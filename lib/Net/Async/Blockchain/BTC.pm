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
use Future::Utils qw( fmap_void );

use Net::Async::Blockchain::Transaction;
use Net::Async::Blockchain::Client::RPC::BTC;
use Net::Async::Blockchain::Client::ZMQ;

use parent qw(Net::Async::Blockchain);

use constant DEFAULT_CURRENCY => 'BTC';

my %subscription_dictionary = ('transactions' => 'rawtx');

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
        $self->add_child(
            my $http_client = Net::Async::Blockchain::Client::RPC::BTC->new(
                endpoint     => $self->rpc_url,
                rpc_user     => $self->rpc_user,
                rpc_password => $self->rpc_password
            ));
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
    return $self->new_zmq_client->subscribe($subscription)->map(async sub { return await $self->$subscription(shift) })->ordered_futures;
}

=head2 transform_transaction

Receive a decoded raw transaction and convert it to a L<Net::Async::Blockchain::Transaction> object

=over 4

=item * C<decoded_raw_transaction> the response from the command `decoderawtransaction`

=back

L<Net::Async::Blockchain::Transaction>

=cut

async sub rawtx {
    my ($self, $raw_transaction) = @_;

    my $decoded_raw_transaction = await $self->rpc_client->_request('decoderawtransaction', $raw_transaction);
    # this will guarantee that the transaction is from our node
    # txindex must to be 0
    my $received_transaction = await $self->rpc_client->get_transaction($decoded_raw_transaction->{txid});

    # transaction not found, just ignore.
    return undef unless $received_transaction;

    my $fee   = Math::BigFloat->new($received_transaction->{fee} // 0);
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

        my @categories       = keys %categories;
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

    return @transactions;
}

1;
