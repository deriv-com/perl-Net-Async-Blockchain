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

use Net::Async::Blockchain::Transaction;
use Net::Async::Blockchain::Client::RPC::BTC;
use Net::Async::Blockchain::Client::ZMQ;
use IO::Async::Timer::Periodic;

use parent qw(Net::Async::Blockchain);

use constant DEFAULT_CURRENCY => 'BTC';

my %subscription_dictionary = ('transactions' => 'rawtx');

sub pending_transactions {
    return shift->{pending_transactions} // [];
}

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

sub zmq_client {
    my ($self) = @_;
    return $self->{zmq_client} //= do {
        $self->add_child(
            $self->{zmq_client} = Net::Async::Blockchain::Client::ZMQ->new(
                endpoint    => $self->subscription_url,
                timeout     => $self->subscription_timeout,
                msg_timeout => $self->subscription_msg_timeout,
            ));
        $self->{zmq_client};
    }
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

    # every minute try to reprocess the pending transactions
    my $pending_transaction_timer = IO::Async::Timer::Periodic->new(
        first_interval => 10,
        interval       => 60,
        on_tick        => sub {
            # we could be using Future::Queue here instead but
            # since we don't want to lock the execution at this
            # point is better to just use an array
            my $counter = 0;
            while (my $pending_transaction = shift $self->{pending_transactions}->@*) {
                # process only this amount per time to not delay the new transactions
                last if $counter > 100;
                $self->zmq_client->source->emit($pending_transaction);
                $counter++;
            }
        });

    $self->add_child($pending_transaction_timer);
    $pending_transaction_timer->start;

    return $self->zmq_client->subscribe($subscription)->map(
        async sub {
            my $transaction = shift;
            # raw transaction
            return await $self->transform_raw_transaction($transaction) if length($transaction) > 64;
            # transaction hash
            return await $self->transform_transaction($transaction);
        })->ordered_futures->filter(sub { $_ });

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
    my ($self, $block_number) = @_;

    # that is nothing to do
    return undef unless $block_number;

    my $current_block = await $self->rpc_client->get_last_block();
    # no matter if it is an error or not we can't proceed without the last block
    return $block_number unless $current_block;

    my $block_number_counter = $block_number;
    while ($current_block >= $block_number_counter) {
        my $block_hash = await $self->rpc_client->get_block_hash($block_number_counter);
        return $block_number_counter unless $block_hash;

        # 2 here means the full verbosity since we want to get the raw transactions
        my $block_response = await $self->rpc_client->get_block($block_hash, 2);
        return $block_number_counter unless $block_response;

        push($self->{pending_transactions}->@*, $block_response->{tx}->@*);
        $self->emit_block($block_number_counter);
        $block_number_counter++;
    }

    return undef;
}

=head2 transform_raw_transaction

Same as transform_transaction but deserialize the raw transaction first

=over 4

=item * C<raw_transaction> encoded raw transaction

=back

L<Net::Async::Blockchain::Transaction>

=cut

async sub transform_raw_transaction {
    my ($self, $raw_transaction) = @_;

    # TODO: remove the node request to decode the transaction adding a proper perl conversion for it
    # this will return null if the txindex is equals 0 and the transaction is not from the local node
    my ($decoded_raw_transaction, $error) = await $self->rpc_client->decode_raw_transaction($raw_transaction);

    if ($error) {
        push($self->{pending_transactions}->@*, $raw_transaction);
        return undef;
    }

    # transaction not found, because it is not related to the local node
    return undef unless $decoded_raw_transaction;

    return await $self->transform_transaction($decoded_raw_transaction);
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

    # this returns only the details related to the local node in case of txindex equals 0
    my ($received_transaction, $error) = await $self->rpc_client->get_transaction($decoded_raw_transaction->{txid});

    if ($error) {
        push($self->{pending_transactions}->@*, $decoded_raw_transaction->{txid});
        return undef;
    }

    # transaction not found, because it is not related to the local node
    return undef unless $received_transaction;

    my $fee = Math::BigFloat->new($received_transaction->{fee} // 0);
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
            block        => $received_transaction->{blockhash},
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
