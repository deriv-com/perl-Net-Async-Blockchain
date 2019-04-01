package Net::Async::Blockchain::BTC;

use strict;
use warnings;
no indirect;

use JSON;
use Ryu::Async;
use Future::AsyncAwait;
use IO::Async::Loop;
use List::Util qw(first);
use Math::BigFloat;

use Net::Async::Blockchain::Client::RPC;
use Net::Async::Blockchain::Subscription::ZMQ;

use base qw(Net::Async::Blockchain);

use constant DEFAULT_LOOKUP_TRANSACTIONS => 100;

sub currency_code { 'BTC' }

sub rpc_client : method {
    my ($self) = @_;
    return $self->{rpc_client} if $self->{rpc_client};

    $self->add_child(
        my $http_client = Net::Async::Blockchain::Client::RPC->new(endpoint => $self->config->{rpc_url})
    );

    return $http_client;
}

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

sub subscribe {
    my ($self, $subscription) = @_;

    my $url = $self->config->{subscription_url};

    die "Invalid or not implemented subscription" unless $subscription && $self->can($subscription);
    my $zmq_source = $self->new_zmq_client->subscribe($subscription);
    die "Can't connect to ZMQ" unless $zmq_source;
    $zmq_source->each(async sub { await $self->$subscription(shift) });

    return $self->source;
}

async sub rawtx {
    my ($self, $raw_transaction) = @_;

    my $decoded_raw_transaction = await $self->rpc_client->decoderawtransaction($raw_transaction);
    my $transaction = await $self->transform_transaction($decoded_raw_transaction);

    $self->source->emit($transaction) if $transaction;
}

async sub transform_transaction {
    my ($self, $decoded_raw_transaction) = @_;

    my @received_transactions = grep { $_->{txid} eq $decoded_raw_transaction->{txid} }
        @{await $self->rpc_client->listtransactions("*", $self->config->lookup_transactions // DEFAULT_LOOKUP_TRANSACTIONS)};

    # transaction not found, just ignore.
    return undef unless @received_transactions;

    my $amount = Math::BigFloat->bzero();
    my %addresses;
    my %category;
    my $fee = Math::BigFloat->bzero();

    for my $tx (@received_transactions) {
        $amount->badd($tx->{amount});
        $addresses{$tx->{address}} = 1;
        $category{$tx->{category}} = 1;
        # for received transactions the fee will not be available.
        $fee->badd($tx->{fee}) if $tx->{fee};
    }
    my @addresses = keys %addresses;
    my @categories = keys %category;
    my $transaction_type = scalar @categories > 1 ? 'internal' : $categories[0];

    my $transaction = {
        currency => $self->currency_code,
        hash => $decoded_raw_transaction->{txid},
        from => '',
        to => \@addresses,
        amount => $amount,
        fee => $fee,
        fee_currency => $self->currency_code,
        type => $transaction_type,
    };

    return $transaction;
}

1;

