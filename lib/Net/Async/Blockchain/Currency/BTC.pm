package Net::Async::Blockchain::Currency::BTC;

use strict;
use warnings;
no indirect;

our $VERSION = '0.001';

use Moo;
use List::Util qw(first);
use JSON;
use Net::Async::Blockchain::Client::RPC;
use Net::Async::Blockchain::Subscription::ZMQ;
extends 'Net::Async::Blockchain::Config';

sub currency_code {
    return 'BTC';
}

has rpc_client => (
    is => 'lazy',
);

sub _build_rpc_client {
    my ($self) = @_;
    return Net::Async::Blockchain::Client::RPC->new(url => $self->config->{rpc_url});
}

has zmq_client => (
    is => 'lazy',
);

sub _build_zmq_client {
    my ($self) = @_;
    $self->loop->add(my $zmq_source = Ryu::Async->new());
    $self->loop->add(my $zmq_client = Net::Async::Blockchain::Subscription::ZMQ->new(
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
    $zmq_source->each(sub { $self->$subscription(shift) });

    return $self->source;
}

sub rawtx {
    my ($self, $raw_transaction) = @_;
    $self->rpc_client->decoderawtransaction($raw_transaction)->then(
        sub {
            my ($decoded_transaction) = @_;
            my @addresses = map { $_->{scriptPubKey}->{addresses}->@* } $decoded_transaction->{vout}->@*;
            return $self->_find_address(@addresses)->then(
                sub {
                    my $response = shift;
                    $self->source->emit($decoded_transaction) if $response;
                    Future->done();
                });
        })->get;

}

sub _find_address {
    my ($self, @addresses) = @_;

    return $self->rpc_client->listreceivedbyaddress(0, JSON->true)->then(
        sub {
            for my $address (@addresses) {
                if (first { $_->[0]->{address} eq $address } @_) {
                    return Future->done(1);
                }
            }
            Future->done(0);
        });
}

1;

