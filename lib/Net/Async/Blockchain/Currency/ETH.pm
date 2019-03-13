package Net::Async::Blockchain::Currency::ETH;

use strict;
use warnings;
no indirect;

our $VERSION = '0.001';

use Moo;
use Net::Async::Blockchain::Subscription::Websocket;
use Ryu::Async;
use JSON::MaybeUTF8 qw(decode_json_utf8);

extends 'Net::Async::Blockchain::Config';

sub currency_code {
    return 'ETH';
}

has client => (
    is => 'lazy',
);

sub _build_client {
    my ($self) = @_;
    $self->loop->add(my $ws_source = Ryu::Async->new());
    $self->loop->add(my $client = Net::Async::Blockchain::Subscription::Websocket->new(
        on_text_frame => sub {
            my ($s, $frame) = @_;
            $s->source->emit(decode_json_utf8($frame));
        },
        endpoint => $self->config->{subscription_url},
        source => $ws_source->source,
    ));
    return $client;
}

sub subscribe {
    my ($self, $subscription) = @_;

    return undef unless $self->can($subscription);
    $self->client->eth_subscribe($subscription)->each(sub{$self->$subscription(shift)});

    return $self->source;
}

sub newHeads {
    my ($self) = @_;
    $self->source->emit(@_);
}

1;

