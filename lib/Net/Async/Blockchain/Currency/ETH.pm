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
        endpoint => $self->config->{subscription_url},
        source => $ws_source->source,
    ));
    return $client;
}

sub subscribe {
    my ($self, $subscription) = @_;

    return undef unless $self->can($subscription);
    use Data::Dumper;
    $self->client->eth_subscribe(1, $subscription)
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
    $self->client->eth_getBlockByHash(2, $block->{hash}, JSON->true)
        ->filter(id => 2)
        ->each(sub{$self->normalize_transactions(shift->{transactions})});
}

sub normalize_transactions{
    my ($self, @transactions) = @_;
    for my $blk_transaction (@transactions) {
        my $transaction = {
            currency => $self->currency_code,
            hash => $blk_transaction->{hash},
            from => $blk_transaction->{from},
            to => $blk_transaction->{to},
            amount => $blk_transaction->{value},
            # fee =>
            # fee_currency => $self->currency_code,
            # type =>
        };

        $self->source->emit(encode_json_utf8($transaction));
    }
}

1;

