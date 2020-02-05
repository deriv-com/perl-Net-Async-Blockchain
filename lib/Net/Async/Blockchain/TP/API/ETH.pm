package Net::Async::Blockchain::TP::API::ETH;

=head1 Net::Async::Blockchain::TP::API::ETH

This class is responsible to check and request transactions from
third party APIs, actually this supports etherscan and blockscout

=cut

use strict;
use warnings;
no indirect;

our $VERSION = '0.001';

use Future::AsyncAwait;
use Net::Async::HTTP;
use JSON::MaybeUTF8 qw(decode_json_utf8);
use Syntax::Keyword::Try;
use Log::Any qw($log);
use File::ShareDir;
use YAML::XS;

use parent qw(IO::Async::Notifier);

=head2 configure

Any additional configuration that is not described on L<IO::Async::Notifier>
must be included and removed here.

=over 4

=item * C<tp_api_config>

=back

=cut

sub configure {
    my ($self, %params) = @_;

    for my $k (qw(tp_api_config)) {
        $self->{$k} = delete $params{$k} if exists $params{$k};
    }

    $self->SUPER::configure(%params);
}

=head2 http_client

Create a new L<Net::Async::HTTP> instance.
Return a L<Net::Async::HTTP> if already not declared otherwise
return the same instance.

=cut

sub http_client {
    my ($self) = @_;

    return $self->{http_client} //= do {
        $self->add_child(
            my $http_client = Net::Async::HTTP->new(
                decode_content => 1,
            ));

        $http_client;
    };
}

=head2 config

Return the third party API config

=cut

sub config {
    my $self = shift;
    return $self->{tp_api_config} //= do {
        my $tp_api_config = YAML::XS::LoadFile(File::ShareDir::dist_file('Net-Async-Blockchain', 'tp_api_config.yml'));
        $tp_api_config->{ETH}->{thirdparty_api};
    };
}

=head2 latest_call

Return the last time we have called the third party API

=cut

sub latest_call {
    my $self = shift;
    return $self->{latest_call} //= time;
}

=head2 latest_counter

Return the API calling counter value

=cut

sub latest_counter {
    my $self = shift;
    return $self->{latest_counter} //= 0;
}

=head2 check_call_limit

Guarantee we are doing only 5 requests per second for the third
party APIs

Return 1 when is safe include one more request and 0 when no more requests
can be added.

=cut

async sub check_call_limit {
    my $self = shift;

    my $status = 1;
    if ($self->latest_call() == time) {
        $self->{latest_counter}++;
        if ($self->latest_counter() >= 5) {
            await $self->loop->delay_future(after => 1);
            $self->{latest_call}    = time;
            $self->{latest_counter} = 0;
            $status                 = 0;
        }
    }

    return $status;
}

=head2 create_url

Generate the URL based on the passed arguments.

=cut

sub create_url {
    my ($self, $api, $args) = @_;

    my $api_url = $api->{url};
    my $token   = $api->{token};

    my $url = sprintf("%s?module=account&%s", $api_url, $args);
    $url .= sprintf("&apikey=%s", $token) if $token;
    return $url;
}

=head2 get_internal_transactions_by_address

Request from API using the address as parameter
all the contract internal transactions for this address.

=over 4

=item* C<$address> address
=item* C<$start_block> the number of first block
=item* C<$end_block> the number of last block

=back

Return an array reference containing all internal transactions for this address

=cut

async sub get_internal_transactions_by_address {
    my ($self, $address, $start_block, $end_block) = @_;
    my $api_args = sprintf("action=txlistinternal&address=%s&startblock=%s&endblock=$s&sort=asc", $address, $start_block, $end_block);
    return await $self->request($api_args);
}

=head2 get_internal_transactions_by_txn_hash

Request from API using the transaction hash as parameter
all the contract internal transactions for this transaction hash.

=over 4

=item* C<$txn_hash> transaction hash

=back

Return an array reference containing all internal transactions for this transaction hash

=cut

async sub get_internal_transactions_by_txn_hash {
    my ($self, $txn_hash) = @_;
    my $api_args = sprintf("action=txlistinternal&txhash=%s",$txn_hash);
    return await $self->request($api_args);
}

=head2 get_amount_for_internal_transaction

Get the internal transactions by the parent transaction hash
Then return the amount for the passed address

=over 4

=item* C<$address> address
=item* C<$transaction_hash> parent transaction hash

=back

Numeric transaction value

=cut

async sub get_amount_for_internal_transaction {
    my ($self, $address, $transaction_hash) = @_;

    my $internal_transactions = await $self->get_internal_transactions_by_txn_hash($transaction_hash);
    return 0 unless $internal_transactions;

    my $amount = 0;
    for my $internal ($internal_transactions->@*) {
        next if $internal->{value} <= 0 || $internal->{type} ne 'call' || $internal->{isError} || $internal->{to} ne $address;
        $amount += $internal->{value};
    }
    return $amount;
}

=head2 request

List all APIs available in the configuration file and do the request for each one them
until receive the response.

=over 4

=item* C<$api_args> API arguments

=back

Returns the request response

=cut

async sub request {
    my ($self, $api_args) = @_;

    await $self->check_call_limit();

    # we could just use `keys $self->config->%*` here but since we want this
    # in this specific order we are fixing the API names here, the etherscan API
    # generally answer faster than the blockscout, so better to leave blockscout as
    # the backup one.
    for my $thirdparty_api (qw(etherscan blockscout)) {
        my $url = $self->create_url($self->config->{$thirdparty_api}, $api_args);

        try {
            my $response = await $self->http_client->GET($url);
            my $decoded_response = decode_json_utf8($response->decoded_content);
            return $decoded_response->{result} if $decoded_response->{result} && $decoded_response->{status} == 1;
            # This means that the response was ok but no result has been found
            return undef;
        }
        catch {
            $log->warnf("Can't get response from $method to the $thirdparty_api for $address");
        }
    }

    $log->warnf("Can't get any response from third party APIs for the address: $address");
    return undef;
}

1;
