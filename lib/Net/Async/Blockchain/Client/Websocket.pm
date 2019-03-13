package Net::Async::Blockchain::Client::Websocket;

use strict;
use warnings;
no indirect;

our $VERSION = '0.001';

use Moo;
use IO::Async::Loop;
use Ryu::Async;
use JSON::MaybeUTF8 qw(encode_json_utf8 decode_json_utf8);
use Net::Async::WebSocket::Client;

has url => (
    is => 'ro',
);

has _loop => (
    is => 'lazy',
);

sub _build__loop {
    return IO::Async::Loop->new();
}

has _source => (
    is => 'lazy',
);

sub _build__source {
    my ($self) = @_;
    $self->_loop->add(my $ryu = Ryu::Async->new());
    return $ryu->source;
}

has _ws_client => (
    is => 'lazy',
);

sub _build__ws_client {
    my ($self) = @_;
    my $client = Net::Async::WebSocket::Client->new(
        on_text_frame => sub {
            my ($s, $frame) = @_;
            $self->_source->emit(decode_json_utf8($frame));
        }
    );
    $self->_loop->add($client);
    return $client;
}

sub AUTOLOAD {
    my $self = shift;

    my $method = $Net::Async::Blockchain::Client::Websocket::AUTOLOAD;
    $method =~ s/.*:://;

    return if ($method eq 'DESTROY');

    my $obj = {
        id     => 1,
        method => $method,
        params => (ref $_[0] ? $_[0] : [@_]),
    };

    $self->_ws_client->connect(url => $self->url)->then(sub {
            $self->_ws_client->send_text_frame(encode_json_utf8($obj));
        })->get;

    $self->_loop->run();
    return $self->_source;
}

1;

