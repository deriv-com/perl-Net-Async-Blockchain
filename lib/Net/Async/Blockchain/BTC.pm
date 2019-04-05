package Net::Async::Blockchain::BTC;

use strict;
use warnings;

our $VERSION = '0.001';

=head1 NAME

Net::Async::Blockchain::BTC - Bitcoin based subscription.

=head1 SYNOPSIS

    my $btc_args = {
        subscription_url => "tcp://127.0.0.1:28332",
        rpc_url => 'http://test:test@127.0.0.1:8332',
        rpc_timeout => 100,
        lookup_transactions => 10,
    };

    my $loop = IO::Async::Loop->new;

    $loop->add(
        my $btc_client = Net::Async::Blockchain::BTC->new(
            config => $btc_args
        )
    );

    $btc_client->subscribe("rawtx")->each(sub { print shift->{hash} });

    $loop->run();


=head1 DESCRIPTION

Bitcoin subscription using ZMQ from the bitcoin based blockchain nodes

=over 4

=cut

no indirect;

use JSON;
use Ryu::Async;
use Future::AsyncAwait;
use IO::Async::Loop;
use Math::BigFloat;

use Net::Async::Blockchain::Transaction;
use Net::Async::Blockchain::Client::RPC;
use Net::Async::Blockchain::Subscription::ZMQ;

use base qw(Net::Async::Blockchain);

use constant DEFAULT_LOOKUP_TRANSACTIONS => 100;

sub currency_code { 'BTC' }

sub new_zmq_client {
    my ($self) = @_;
    $self->add_child(my $zmq_source = Ryu::Async->new);
    $self->add_child(
        my $zmq_client = Net::Async::Blockchain::Subscription::ZMQ->new(
            source   => $zmq_source->source,
            endpoint => $self->config->{subscription_url},
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

    my $url = $self->config->{subscription_url};

    die "Invalid or not implemented subscription" unless $subscription && $self->can($subscription);
    my $zmq_source = $self->new_zmq_client->subscribe($subscription);
    die "Can't connect to ZMQ" unless $zmq_source;
    $zmq_source->each(async sub { await $self->$subscription(shift) });

    return $self->source;
}

=head2 rawtx

rawtx subscription

Convert and emit a L<Net::Async::Blockchain::Transaction> for the client source every new raw transaction received that
is owned by the node.

=over 4

=item * C<raw_transaction> bitcoin raw transaction

=back

=cut

async sub rawtx {
    my ($self, $raw_transaction) = @_;

    my $decoded_raw_transaction = await $self->rpc_client->decoderawtransaction($raw_transaction);
    my $transaction = await $self->transform_transaction($decoded_raw_transaction);

    $self->source->emit($transaction) if $transaction;
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
    my @received_transactions = grep { $_->{txid} eq $decoded_raw_transaction->{txid} }
        @{await $self->rpc_client->listtransactions("*", $self->config->{lookup_transactions} // DEFAULT_LOOKUP_TRANSACTIONS)};

    # transaction not found, just ignore.
    return undef unless @received_transactions;

    my $amount = Math::BigFloat->bzero();
    my %addresses;
    my %category;
    my $fee = Math::BigFloat->bzero();

    # we can have more than one transaction when:
    # - multiple `to` addresses transactions
    # - sent and received by the same node
    for my $tx (@received_transactions) {
        $amount->badd($tx->{amount});
        $addresses{$tx->{address}} = 1;
        $category{$tx->{category}} = 1;
        # for received transactions the fee will not be available.
        $fee->badd($tx->{fee}) if $tx->{fee};
    }
    my @addresses = keys %addresses;
    my @categories = keys %category;
    # it can be receive, sent, internal, if we have a send and a receive transaction
    # this means that the node sent a transaction to an address that it is the owner too.
    my $transaction_type = scalar @categories > 1 ? 'internal' : $categories[0];

    my $transaction = Net::Async::Blockchain::Transaction->new(
        currency => $self->currency_code,
        hash => $decoded_raw_transaction->{txid},
        block => $decoded_raw_transaction->{locktime},
        from => '',
        to => \@addresses,
        amount => $amount,
        fee => $fee,
        fee_currency => $self->currency_code,
        type => $transaction_type,
    );

    return $transaction;
}

1;

