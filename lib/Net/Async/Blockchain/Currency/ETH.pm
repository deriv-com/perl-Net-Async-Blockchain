package Net::Async::Blockchain::Currency::ETH;

use strict;
use warnings;
no indirect;

use Moo;
use Net::Async::Blockchain::Subscription::Websocket;
use Ryu::Async;
use JSON::MaybeUTF8 qw(decode_json_utf8 encode_json_utf8);
use JSON;

extends 'Net::Async::Blockchain::Config';

sub currency_code {
    return 'ETH';
}

has subscription_id => (
    is => 'rw',
);

sub _get_new_client {
    my ($self) = @_;
    $self->loop->add(my $ws_source = Ryu::Async->new());
    $self->loop->add(my $client = Net::Async::Blockchain::Subscription::Websocket->new(
        endpoint => $self->config->{subscription_url},
        source => $ws_source->source,
    ));
    return $client;
}

sub subscribe {
    my ($self, $subscription) = @_;

    return undef unless $self->can($subscription);
    $self->_get_new_client->eth_subscribe(1, $subscription)
        ->skip_until(sub{
                my $response = shift;
                return 1 unless $response->{result};
                return 0 if $self->subscription_id($response->{result});
            })
        ->filter(sub {
                my $response = shift;
                return undef unless $response->{params} && $response->{params}->{subscription};
                return $response->{params}->{subscription} eq $self->subscription_id;
            })
        ->each(sub{$self->$subscription(shift)});

    return $self->source;
}

sub newHeads {
    my ($self, $response) = @_;

    return undef unless $response->{params} && $response->{params}->{result};
    my $block = $response->{params}->{result};

    $self->_get_new_client->eth_getBlockByHash(2, $block->{hash}, JSON->false)
        ->filter(id => 2)
        ->take(1)
        ->each(sub{$self->source->emit(shift)});
}

1;

