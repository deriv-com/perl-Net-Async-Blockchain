package Net::Async::Blockchain::Omni;

use strict;
use warnings;

our $VERSION = '0.001';

=head1 NAME

Net::Async::Blockchain::Omni - Omnicore based subscription.

=head1 SYNOPSIS

    my $loop = IO::Async::Loop->new;

    $loop->add(
        my $omni_client = Net::Async::Blockchain::Omni->new(
            subscription_url => "tcp://127.0.0.1:28332",
            rpc_url => 'http://127.0.0.1:8332',
            rpc_user => 'test',
            rpc_password => 'test',
            rpc_timeout => 100,
        )
    );

    $omni_client->subscribe("transactions")->each(sub { print shift->{hash} })->get;

=head1 DESCRIPTION

Omnicore subscription using ZMQ from the bitcoin based blockchain nodes

=over 4

=back

=cut

no indirect;

use Ryu::Async;
use Future;
use Future::AsyncAwait;
use IO::Async::Loop;
use Math::BigFloat;
use Syntax::Keyword::Try;
use Future::Utils qw( fmap_void );

use Net::Async::Blockchain::Transaction;
use Net::Async::Blockchain::Client::RPC::Omni;

use parent qw(Net::Async::Blockchain::BTC);

# fee for Omnicore is always BTC
use constant FEE_CURRENCY => 'BTC';

my %subscription_dictionary = ('transactions' => 'hashblock');

=head2 rpc_client

Create an L<Net::Async::Blockchain::Client::RPC> instance, if it is already defined just return
the object

=over 4

=back

L<Net::Async::Blockchain::Client::RPC>

=cut

sub rpc_client : method {
    my ($self) = @_;
    return $self->{rpc_client} //= do {
        $self->add_child(
            my $http_client = Net::Async::Blockchain::Client::RPC::Omni->new(
                endpoint     => $self->rpc_url,
                rpc_user     => $self->rpc_user,
                rpc_password => $self->rpc_password
            ));
        $http_client;
    };
}

=head2 subscribe

Connect to the ZMQ port and subscribe to the implemented subscription:
- https://github.com/bitcoin/bitcoin/blob/master/doc/zmq.md#usage

=over 4

=item * C<subscription> string subscription name

=back

L<Ryu::Source>

=cut

sub subscribe {
    my ($self, $subscription) = @_;

    # rename the subscription to the correct blockchain node subscription
    $subscription = $subscription_dictionary{$subscription};

    die "Invalid or not implemented subscription" unless $subscription && $self->can($subscription);
    my $zmq_client_source = $self->zmq_client->subscribe($subscription);

    my $error_handler = sub {
        my $error = shift;
        $self->source->fail($error) unless $self->source->completed->is_ready;
        zmq_close($self->zmq_client->socket_client());
    };

    Future->needs_all(
        $zmq_client_source->each(sub { my $block_hash = shift; $self->new_blocks_queue->push($block_hash); })->completed,
        $self->recursive_search()->then(
            async sub {
                while (1) {
                    my $block_number = await $self->hashblock(await $self->new_blocks_queue->shift);
                    $self->emit_block($block_number);
                }
            }))->on_fail($error_handler)->retain;

    return $self->source;
}

=head2 recursive_search

go into each block starting from the C<base_block_number> searching
for transactions from the node, this is usually needed when you stop
the subscription and need to check the blocks since the last one that
you received.

=over 4

=back

=cut

async sub recursive_search {
    my ($self) = @_;

    return undef unless $self->base_block_number;

    my $current_block = await $self->rpc_client->get_last_block();
    die 'unable to get the last block from the node.' unless $current_block;

    my $block_number_counter = $self->base_block_number;
    while ($current_block >= $block_number_counter) {
        my $block_hash = await $self->rpc_client->get_block_hash($block_number_counter);
        die "Failed to get the block hash for block number: $block_number_counter" unless $block_hash;

        my $block_number = await $self->hashblock($block_hash);
        $self->emit_block($block_number);
        $block_number_counter++;
    }

    return undef;
}

=head2 hashblock

hashblock subscription

Convert and emit a L<Net::Async::Blockchain::Transaction> for the client source every new raw transaction received that
is owned by the node.

=over 4

=item * C<raw_transaction> bitcoin raw transaction

=back

=cut

async sub hashblock {
    my ($self, $block_hash) = @_;

    # 2 here means the full verbosity since we want to get the raw transactions
    my $block_response = await $self->rpc_client->get_block($block_hash, 2);
    die sprintf("%s: Can't reach response for block %s", $self->currency_symbol, $block_hash) unless $block_response;

    my @transactions = map { $_->{block} = $block_response->{height}; $_ } $block_response->{tx}->@*;

    await fmap_void { $self->transform_transaction(shift) } foreach => \@transactions,
        concurrent                                                  => 3;

    return $block_response->{height};
}

=head2 transform_transaction

Receive a decoded raw transaction and convert it to a L<Net::Async::Blockchain::Transaction> object

=over 4

=item * C<decoded_raw_transaction> the response from the command `decoderawtransaction`

=back

L<Net::Async::Blockchain::Transaction>

=cut

async sub transform_transaction {
    my ($self, $decoded_raw_transaction) = @_;

    # the command listtransactions will guarantee that this transactions is from or to one
    # of the node addresses.
    my $omni_transaction;

    try {
        $omni_transaction = await $self->rpc_client->get_transaction($decoded_raw_transaction->{txid});
    } catch {
        # transaction not found
        return undef;
    }

    # transaction not found, just ignore.
    return undef unless $omni_transaction && $omni_transaction->{ismine};

    my @transaction = await $self->_process_transaction($omni_transaction);

    for my $transaction (@transaction) { $self->source->emit($transaction); }

    return 1;
}

=head2 _process_transaction

Receives raw transactions and process it to a L<Net::Async::Blockchain::Transaction> object

=over 4

=item * C<omni_transaction> the response from the command `omni_gettransaction`

=back

Return an array.

=cut

async sub _process_transaction {
    my ($self, $omni_transaction) = @_;

    my (@transaction, %sendall, $amount, $transaction_type);

    $amount = Math::BigFloat->new($omni_transaction->{amount}) if ($omni_transaction->{amount});
    my $fee   = Math::BigFloat->new($omni_transaction->{fee} // 0);
    my $block = Math::BigInt->new($omni_transaction->{block});

    my ($from, $to) = await $self->mapping_address($omni_transaction);

    my $count = 0;
    my ($to_response, $from_response);

    $from_response = await $self->rpc_client->list_by_addresses($from->{address});
    if ($from_response && @$from_response) {
        $transaction_type = 'send';
        $count++;
    }

    $to_response = await $self->rpc_client->list_by_addresses($to->{address});
    if ($to_response && @$to_response) {
        $transaction_type = 'receive';
        $count++;
    }
    if ($count > 1) {
        $transaction_type = 'internal';
    }

    return () unless $transaction_type;

    if ($omni_transaction->{type} eq "Send All") {

        for my $data ($omni_transaction->{subsends}->@*) {
            $sendall{$data->{propertyid}} = $data->{amount};
        }

        for my $propertyid (keys %sendall) {

            push @transaction, Net::Async::Blockchain::Transaction->new(

                currency     => $self->currency_symbol,
                hash         => $omni_transaction->{txid},
                block        => $block,
                from         => $from->{address},
                to           => $to->{address},
                amount       => Math::BigFloat->new($sendall{$propertyid}),
                fee          => $fee,
                fee_currency => FEE_CURRENCY,
                type         => $transaction_type,
                property_id  => $propertyid,
                timestamp    => $omni_transaction->{blocktime},
            );
        }

    } else {

        @transaction = Net::Async::Blockchain::Transaction->new(

            currency     => $self->currency_symbol,
            hash         => $omni_transaction->{txid},
            block        => $block,
            from         => $from->{address},
            to           => $to->{address},
            amount       => $amount,
            fee          => $fee,
            fee_currency => FEE_CURRENCY,
            type         => $transaction_type,
            property_id  => $omni_transaction->{propertyid},
            timestamp    => $omni_transaction->{blocktime},
        );
    }

    return @transaction if @transaction;

    return ();

}

=head2 mapping_address

Maps the FROM and TO addresses.

=over 4

=item * C<omni_transaction> the response from the command `omni_gettransaction`

=back

L<Future>

=cut

sub mapping_address {

    my ($self, $omni_transaction) = @_;
    return Future->needs_all(map { $self->rpc_client->validate_address($omni_transaction->{$_}) } qw(sendingaddress referenceaddress));
}

1;
