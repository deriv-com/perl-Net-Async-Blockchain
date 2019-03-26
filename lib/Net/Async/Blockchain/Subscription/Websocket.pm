package Net::Async::Blockchain::Subscription::Websocket;

use strict;
use warnings;
no indirect;

use JSON::MaybeUTF8 qw(encode_json_utf8 decode_json_utf8);

use parent qw(Net::Async::WebSocket::Client);

sub source : method { shift->{source} }

sub endpoint : method { shift->{endpoint} }

sub _init {
    my ($self, $paramref) = @_;
    $self->SUPER::_init;

    for my $k (qw(endpoint source)) {
        $self->{$k} = delete $paramref->{$k} if exists $paramref->{$k};
    }

    $self->{framebuffer} = Protocol::WebSocket::Frame->new(max_payload_size => 0);
}

sub AUTOLOAD {
    my $self = shift;

    my $method = $Net::Async::Blockchain::Subscription::Websocket::AUTOLOAD;
    $method =~ s/.*:://;

    return if ($method eq 'DESTROY');

    my $id = shift;

    my $obj = {
        id     => $id,
        method => $method,
        params => (ref $_[0] ? $_[0] : [@_]),
    };

    $self->configure(
        on_text_frame => sub {
            my ($s, $frame) = @_;
            $s->source->emit(decode_json_utf8($frame));
        },
    );

    $self->connect(url => $self->endpoint)->then(
        sub {
            $self->send_text_frame(encode_json_utf8($obj));
        })->get;

    return $self->source;
}

1;

