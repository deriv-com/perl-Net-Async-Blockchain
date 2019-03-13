package Net::Async::Blockchain::Currency::ETH;

use strict;
use warnings;
no indirect;

our $VERSION = '0.001';

use Moo;
use Net::Async::Blockchain::Client::Websocket;
extends 'Net::Async::Blockchain::Config';

sub currency_code {
    return 'ETH';
}

has client => (
    is => 'lazy',
);

sub _build_client {
    my ($self) = @_;
    return Net::Async::Blockchain::Client::Websocket->new(url => $self->config->{subscription_url});
}

sub subscribe {
    my ($self, $subscription) = @_;

    return undef unless $self->can($subscription);
    $self->client->eth_subscribe($subscription)->each(sub{$self->$subscription(shift)})->get;

    return $self->source;
}

sub newHeads {
    my ($self) = @_;
    $self->source->emit(@_);
}

1;

