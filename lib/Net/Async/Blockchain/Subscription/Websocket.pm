package Net::Async::Blockchain::Subscription::Websocket;

use strict;
use warnings;
no indirect;

our $VERSION = '0.001';

use Moo;
use IO::Async::Loop;
use Ryu::Async;
use JSON::MaybeUTF8 qw(encode_json_utf8 decode_json_utf8);

extends 'Net::Async::WebSocket::Client';

has source => (
    is => 'ro',
);

has endpoint => (
    is => 'ro',
);

sub configure {
    my ($self, %args) = @_;
    for my $k (qw(endpoint source)) {
        $self->{$k} = delete $args{$k} if exists $args{$k};
    }
    $self->next::method(%args);
}

sub send_text_frame {
    my $self = shift;
    my ($text, %params) = @_;

    # Protocol::WebSocket::Frame will UTF-8 encode this for us
    my $frame = Protocol::WebSocket::Frame->new(
        type   => "text",
        buffer => $text,
        masked => $self->{masked},
    );
    $frame->max_payload_size(0);
    $self->write($frame->to_bytes, %params);
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

    $self->connect(url => $self->endpoint)->then(sub {
            $self->send_text_frame(encode_json_utf8($obj));
        })->get;

    return $self->source;
}

1;

