package Net::Async::Blockchain::BTC;

use strict;
use warnings;

our $VERSION = '0.001';

=head1 NAME

Net::Async::Blockchain::BTC - Bitcoin based subscription.

=head1 SYNOPSIS

    my $loop = IO::Async::Loop->new;

    $loop->add(
        my $btc_client = Net::Async::Blockchain::BTC->new(
            subscription_url => "tcp://127.0.0.1:28332",
            rpc_url => 'http://127.0.0.1:8332',
            rpc_user => 'test',
            rpc_password => 'test',
            rpc_timeout => 100,
        )
    );

    $btc_client->subscribe("transactions")->each(sub { print shift->{hash} })->get;

=head1 DESCRIPTION

Bitcoin subscription using ZMQ from the bitcoin based blockchain nodes

=over 4

=back

=cut

no indirect;

use Ryu::Async;
use Future::AsyncAwait;
use IO::Async::Loop;
use Math::BigFloat;
use ZMQ::LibZMQ3;

use Net::Async::Blockchain::Block;
use Net::Async::Blockchain::Transaction;
use Net::Async::Blockchain::Client::RPC::BTC;
use Net::Async::Blockchain::Client::ZMQ;

use parent qw(Net::Async::Blockchain);

use constant DEFAULT_CURRENCY => 'BTC';

my %subscription_dictionary = ('transactions' => 'hashblock');

sub currency_symbol : method { shift->{currency_symbol} // DEFAULT_CURRENCY }

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
        $self->add_child(my $http_client = Net::Async::Blockchain::Client::RPC::BTC->new(endpoint => $self->rpc_url,
                                            rpc_user     => $self->rpc_user,
                                            rpc_password => $self->rpc_password));
        $http_client;
    };
}

=head2 zmq_client

Returns the current instance for L<Net::Async::Blockchain::Client::ZMQ> if not created
create a new one.

=over 4

=back

L<Net::Async::Blockchain::Client::ZMQ>

=cut

sub zmq_client : method {
    my ($self) = @_;
    return $self->{zmq_client} //= do {
        $self->new_zmq_client();
        }
}

=head2 new_zmq_client

Create a new L<Net::Async::Blockchain::Client::ZMQ> instance.

=over 4

=back

L<Net::Async::Blockchain::Client::ZMQ>

=cut

sub new_zmq_client {
    my ($self) = @_;
    $self->add_child(
        $self->{zmq_client} = Net::Async::Blockchain::Client::ZMQ->new(
            endpoint    => $self->subscription_url,
            timeout     => $self->subscription_timeout,
            msg_timeout => $self->subscription_msg_timeout,
            on_shutdown => sub {
                my ($error) = @_;
                warn $error;
                # finishes the final client source
                $self->source->finish();
            }));
    return $self->{zmq_client};
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
    my $zmq_client_source = $self->new_zmq_client->subscribe($subscription);

    my $error_handler = sub {
        my $error = shift;
        $self->source->fail($error) unless $self->source->completed->is_ready;
        zmq_close($self->zmq_client->socket_client());
    };

    Future->needs_all($zmq_client_source->map(async sub { await $self->$subscription(shift) })->ordered_futures->completed(),
        $self->recursive_search())->on_fail($error_handler)->retain;

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

    return undef unless $self->block->number;

    my $current_block = await $self->rpc_client->get_last_block();

    return undef unless $current_block;

    while (1) {
        last unless $current_block > $self->block->number;
        $self->source->emit($self->block);
        my $block_hash = await $self->rpc_client->get_block_hash($self->block->number + 0);
        await $self->hashblock($block_hash) if $block_hash;
        $self->block->up();
    }
    # set block number as undef to inform the recursive search has ended.
    $self->source->emit($self->block->empty());
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

    # block not found or some issue in the RPC call
    unless ($block_response) {
        warn sprintf("%s: Can't reach response for block %s", $self->currency_symbol, $block_hash);
        return undef;
    }

    my @transactions = map { $_->{block} = $block_response->{height}; $_ } $block_response->{tx}->@*;
    for my $transaction (@transactions) {
        await $self->transform_transaction($transaction);
    }
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

    # this will guarantee that the transaction is from our node
    # txindex must to be 0
    my $received_transaction = await $self->rpc_client->get_transaction($decoded_raw_transaction->{txid});

    # transaction not found, just ignore.
    return undef unless $received_transaction;

    my $fee = Math::BigFloat->new($received_transaction->{fee} // 0);
    my $block = Math::BigInt->new($decoded_raw_transaction->{block});
    my @transactions;
    my %addresses;

    # we can have multiple details when:
    # - multiple `to` addresses transactions
    # - sent and received by the same node
    for my $tx ($received_transaction->{details}->@*) {
        my $address = $tx->{address};

        next if $addresses{$address}++;

        my @details = grep { $_->{address} eq $address } $received_transaction->{details}->@*;

        my $amount = Math::BigFloat->bzero();
        my %categories;
        for my $detail (@details) {
            $amount->badd($detail->{amount});
            $categories{$detail->{category}} = 1;
        }

        my @categories = keys %categories;
        my $transaction_type = scalar @categories > 1 ? 'internal' : $categories[0];

        my $transaction = Net::Async::Blockchain::Transaction->new(
            currency     => $self->currency_symbol,
            hash         => $decoded_raw_transaction->{txid},
            block        => $block,
            from         => '',
            to           => $address,
            amount       => $amount,
            fee          => $fee,
            fee_currency => $self->currency_symbol,
            type         => $transaction_type,
            timestamp    => $received_transaction->{blocktime},
        );

        push(@transactions, $transaction);
    }

    for my $transaction (@transactions) {
        $self->source->emit($transaction);
    }

    return 1;
}

1;
