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

has client => (
    is => 'lazy',
);

sub _build_client {
    my ($self) = @_;
    return Net::Async::Blockchain::Client::RPC->new(url => sprintf("http://%s", $self->config->{rpc_url}));
}

sub subscribe {
    my ($self, $subscription) = @_;

    my $url = sprintf("tcp://%s", $self->config->{subscription_url});

    return undef unless $self->can($subscription);
    my $zmq_source = Net::Async::Blockchain::Subscription::ZMQ::subscribe($url, $subscription, sub{$self->$subscription(shift)});
    return undef unless $zmq_source;
    # $zmq_source->each(sub{$self->$subscription(shift)})->get;

    return $self->source;
}

sub rawtx {
    my ($self, $raw_transaction) = @_;

    $self->client->decoderawtransaction($raw_transaction)->then(sub{
        my ($decoded_address) = @_;
        my @addresses = map { $_->{scriptPubKey}->{addresses}->@* } $decoded_address->{vout}->@*;
        return $self->_find_address(@addresses)->then(sub{
            my $response = shift;
            $self->source->emit($decoded_address) if $response;
            Future->done();
        });
    })->get;

}

sub _find_address {
    my ($self, @addresses) = @_;

    return $self->client->listreceivedbyaddress(0, JSON->true)->then(sub{
        for my $address (@addresses) {
            if (first { $_->[0]->{address} eq $address } @_) {
                return Future->done(1);
            }
        }
        Future->done(0);
    });
}

1;

