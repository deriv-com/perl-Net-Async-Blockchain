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
            rpc_url => 'http://test:test@127.0.0.1:8332',
            rpc_timeout => 100,
        )
    );

    $btc_client->subscribe("rawtx")->each(sub { print shift->{hash} });

    $loop->run();


=head1 DESCRIPTION

Bitcoin subscription using ZMQ from the bitcoin based blockchain nodes

=over 4

=back

=cut

no indirect;

use JSON;
use Ryu::Async;
use Future::AsyncAwait;
use IO::Async::Loop;
use Math::BigFloat;

use Net::Async::Blockchain::Transaction;
use Net::Async::Blockchain::Client::RPC;
use Net::Async::Blockchain::Client::ZMQ;

use parent qw(Net::Async::Blockchain);

my %subscription_dictionary = ('transactions' => 'hashblock');

=head2 new_zmq_client

Create a new L<Net::Async::Blockchain::Client::ZMQ> instance.

=over 4

=back

L<Net::Async::Blockchain::Client::ZMQ>

=cut

sub new_zmq_client {
    my ($self) = @_;
    $self->add_child(my $zmq_source = Ryu::Async->new);
    $self->add_child(
        my $zmq_client = Net::Async::Blockchain::Client::ZMQ->new(
            endpoint    => $self->subscription_url,
            timeout     => $self->subscription_timeout,
            msg_timeout => $self->subscription_msg_timeout,
        ));
    return $zmq_client;
}

=head2 subscribe

Connect to the ZMQ port and subscribe to the implemented subscription:
- https://github.com/bitcoin/bitcoin/blob/master/doc/zmq.md#usage

=over 4

=item * C<subscription> string subscription name

=back

L<Ryu::Async>

=cut

sub subscribe {
    my ($self, $subscription) = @_;

    # rename the subscription to the correct blockchain node subscription
    $subscription = $subscription_dictionary{$subscription};

    die "Invalid or not implemented subscription" unless $subscription && $self->can($subscription);
    my $zmq_source = $self->new_zmq_client->subscribe($subscription);
    die "Can't connect to ZMQ" unless $zmq_source;
    $zmq_source->each(async sub { await $self->$subscription(shift) });

    return $self->source;
}

=head2 hashblock

rawtx subscription

Convert and emit a L<Net::Async::Blockchain::Transaction> for the client source every new raw transaction received that
is owned by the node.

=over 4

=item * C<raw_transaction> bitcoin raw transaction

=back

=cut

async sub hashblock {
    my ($self, $block_hash) = @_;

    # 2 here means the full verbosity since we want to get the raw transactions
    my $block_response = await $self->rpc_client->getblock($block_hash, 2);

    my @transactions = map { $_->{block} = $block_response->{height}; $_ } $block_response->{tx}->@*;
    await Future->needs_all(map { $self->transform_transaction($_) } @transactions);
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
    my $received_transaction = await $self->rpc_client->gettransaction($decoded_raw_transaction->{txid});

    # transaction not found, just ignore.
    return undef unless $received_transaction;

    my %addresses;
    my %category;
    my $amount = Math::BigFloat->bzero($received_transaction->{amount});
    my $fee = Math::BigFloat->new($received_transaction->{fee} // 0);

    # we can have multiple details when:
    # - multiple `to` addresses transactions
    # - sent and received by the same node
    for my $tx ($received_transaction->{details}->@*) {
        $addresses{$tx->{address}} = 1;
        $category{$tx->{category}} = 1;
    }
    my @addresses  = keys %addresses;
    my @categories = keys %category;

    # it can be receive, sent, internal
    # if categories has send and receive it means that is an internal transaction
    my $transaction_type = scalar @categories > 1 ? 'internal' : $categories[0];

    my $transaction = Net::Async::Blockchain::Transaction->new(
        currency     => CURRENCY_SYMBOL,
        hash         => $decoded_raw_transaction->{txid},
        block        => $decoded_raw_transaction->{block},
        from         => $self->currency_symbol,
        to           => \@addresses,
        amount       => $amount,
        fee          => $fee,
        fee_currency => $self->currency_symbol,
        type         => $transaction_type,
    );

    $self->source->emit($transaction) if $transaction;

    return 1;
}

1;
