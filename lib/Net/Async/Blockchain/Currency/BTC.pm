package Net::Async::Blockchain::Currency::BTC;

use strict;
use warnings;
no indirect;

our $VERSION = '0.001';

use Moo;
use JSON;
use Future::AsyncAwait;
use Net::Async::Blockchain::Client::RPC;
use Net::Async::Blockchain::Subscription::ZMQ;
use List::Util qw(first);
use Data::Dumper;
use Math::BigFloat;
extends 'Net::Async::Blockchain::Config';

sub currency_code {
    return 'BTC';
}

has rpc_client => (
    is => 'lazy',
);

sub _build_rpc_client {
    my ($self) = @_;
    $self->loop->add(
        my $http_client = Net::Async::Blockchain::Client::RPC->new(endpoint => $self->config->{rpc_url})
    );
    return $http_client;
}

has zmq_client => (
    is => 'lazy',
);

sub _build_zmq_client {
    my ($self) = @_;
    $self->loop->add(my $zmq_source = Ryu::Async->new());
    $self->loop->add(
        my $zmq_client = Net::Async::Blockchain::Subscription::ZMQ->new(
            source   => $zmq_source->source,
            endpoint => $self->config->{subscription_url},
        ));
    return $zmq_client;
}

sub subscribe {
    my ($self, $subscription) = @_;

    my $url = $self->config->{subscription_url};

    return undef unless $self->can($subscription);
    my $zmq_source = $self->zmq_client->subscribe($subscription);
    return undef unless $zmq_source;
    $zmq_source->each(sub { $self->$subscription(shift)->get });

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

    my @received_transactions = grep { $_->{txid} eq $decoded_raw_transaction->{txid} } @{await $self->rpc_client->listtransactions("*", 10)};

    return undef unless @received_transactions;

    my $amount = Math::BigFloat->bzero();
    my %addresses;
    my %category;
    my $fee = Math::BigFloat->bzero();
    for my $tx (@received_transactions) {
        $amount->badd($tx->{amount});
        $addresses{$tx->{address}} = 1;
        $category{$tx->{category}} = 1;
        $fee->new($tx->{fee}) if $tx->{fee};
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

