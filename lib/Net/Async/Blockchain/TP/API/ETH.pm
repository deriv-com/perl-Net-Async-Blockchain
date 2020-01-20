package Net::Async::Blockchain::TP::API::ETH;

=head1 Net::Async::Blockchain::TP::API::ETH
This class is responsible to check and request transactions from
third party APIs, actually this supports etherscan and blockscout
=cut

use strict;
use warnings;
no indirect;

use Future::AsyncAwait;
use Net::Async::HTTP;
use JSON::MaybeUTF8 qw(decode_json_utf8);
use Syntax::Keyword::Try;
use Log::Any qw($log);
use File::ShareDir;

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
=back
Return a L<Net::Async::HTTP> if already not declared otherwise
return the same instance.
=cut

sub http_client : method {
    my ($self) = @_;

    return $self->{http_client} //= do {
        $self->add_child(
            my $http_client = Net::Async::HTTP->new(
                decode_content => 1,
            ));

        $http_client;
    };
}

sub config : method {
    my $self = shift;
    return $self->{tp_api_config} //= do {
        my $tp_api_config = YAML::XS::LoadFile(File::ShareDir::dist_file('Net-Async-Blockchain', 'tp_api_config.yml'));
        $tp_api_config->{ETH}->{thirdparty_api};
    };
}

sub latest_call : method {
    my $self = shift;
    return $self->{latest_call} //= time;
}

sub latest_counter : method {
    my $self = shift;
    return $self->{latest_counter} //= 0;
}

=head2 check_call_limit
Guarantee we are doing only 5 requests per second for the third
party APIs
=back
Return 1 when is safe include one more request and 0 when no more requests
can be added.
=cut

async sub check_call_limit {
    my $self = shift;

    my $status = 1;
    if ($self->latest_call() == time) {
        $self->{latest_counter}++;
        if ($self->latest_counter() == 5) {
            await $self->loop->delay_future(after => 1);
            $self->{latest_call}    = time;
            $self->{latest_counter} = 0;
            $status                 = 0;
        }
    }

    return $status;
}

sub create_url {
    my ($self, $address, $method, $api) = @_;

    my $api_url = $api->{url};
    my $token   = $api->{token};

    my $url = sprintf("%s?module=account&action=%s&address=%s&sort=asc&apikey=%s", $api_url, $method, $address, $token // "");
    return $url;
}

=head2 get_internal_transactions
Request from API using the address as parameter
all the contract internal transactions for this address.
=over4
=item* C<$address> address to list the contract internal transactions
=back
Return an array reference containing all internal transactions for this address
=cut

async sub get_internal_transactions {
    my ($self, $address) = @_;
    return await $self->request($address, "txlistinternal");
}

=head2 get_normal_transactions
Request from API using the address as parameter
all the transactions for this address
=over4
=item* C<$address> address to list the address transactions
=back
Return an array reference containing all the transactions for this address
=cut

async sub get_normal_transactions {
    my ($self, $address) = @_;
    return await $self->request($address, "txlist");
}

=head2 request
List all APIs available in the configuration file and do the request for each one them
until receive the response.
=over4
=item* C<$address> address
=item* C<$method> API method
=back
Returns the request response
=cut

async sub request {
    my ($self, $address, $method) = @_;

    await $self->check_call_limit();

    # we could just use `keys $thridparty_config->%*` here but since we want this
    # in this specific order we are fixing the API names here, the etherscan API
    # generally answer faster than the blockscout, so better to leave blockscout as
    # the backup one.
    for my $thirdparty_api (qw(etherscan blockscout)) {
        my $url = $self->create_url($address, $method, $self->config->{$thirdparty_api});

        my $response = await $self->http_client->GET($url);
        try {
            my $decoded_response = decode_json_utf8($response->decoded_content);
            return $decoded_response->{result} if $decoded_response->{result} && $decoded_response->{status} == 1;
            # This means that the response was ok but no result has been found
            return undef;
        }
        catch {
            $log->debugf("Can't get response from $method to the $thirdparty_api for $address");
        }
    }

    $log->warnf("Can't get any response from third party APIs for the address: $address");
    return undef;
}

=head2 get amount_for_transaction
Search for the specific transaction in the list internal transactions
and get the amount for it.
=over4
=item* C<$address> address
=item* C<$transaction> transaction to be used as filter
=back
Numeric transaction value
=cut

async sub get_amount_for_transaction {
    my ($self, $address, $transaction) = @_;

    my $internal_transactions = await $self->get_internal_transactions($address);
    return 0 unless $internal_transactions;

    for my $internal ($internal_transactions->@*) {
        if (($internal->{hash} // $internal->{transactionHash}) eq $transaction) {
            return $internal->{value};
        }
    }
    return 0;
}

1;
