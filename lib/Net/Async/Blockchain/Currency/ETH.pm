package Net::Async::Blockchain::Currency::ETH;

use strict;
use warnings;
no indirect;

use Moo;
use Net::Async::Blockchain::Subscription::Websocket;
use Ryu::Async;
use JSON::MaybeUTF8 qw(decode_json_utf8);
use JSON;

extends 'Net::Async::Blockchain::Config';

sub currency_code {
    return 'ETH';
}

has client => (
    is => 'lazy',
);

has subscription_id => (
    is => 'rw',
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
    use Data::Dumper;
    $self->client->eth_subscribe($subscription)
        ->skip_until(sub{
                my $response = shift;
                return 1 unless $response->{result};
                return 0 if $self->subscription_id($response->{result});
            })
        ->filter(subscription => $self->subscription_id)
        ->each(sub{$self->$subscription(shift)});

    return $self->source;
}

sub newHeads {
    my ($self, $response) = @_;
    my $block = $response->{params}->{result};
    $self->client->eth_getBlockByHash($block->{hash}, JSON->true)->take(1)->each(sub{$self->source->emit(shift)});
}

sub newPendingTransactions {
    my ($self, $response) = @_;
    $self->source->emit($response);
}

1;

