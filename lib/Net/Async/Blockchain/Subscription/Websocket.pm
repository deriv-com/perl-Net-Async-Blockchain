package Net::Async::Blockchain::Subscription::Websocket;

use strict;
use warnings;
no indirect;

use JSON::MaybeUTF8 qw(encode_json_utf8 decode_json_utf8);

use base qw(IO::Async::Notifier);

sub source : method { shift->{source} }

sub endpoint : method { shift->{endpoint} }

sub _init {
    my ($self, $paramref) = @_;
    $self->SUPER::_init;

    for my $k (qw(endpoint source)) {
        $self->{$k} = delete $paramref->{$k} if exists $paramref->{$k};
    }

}

sub AUTOLOAD {
    my $self = shift;

    my $method = $Net::Async::Blockchain::Subscription::Websocket::AUTOLOAD;
    $method =~ s/.*:://;

    return if ($method eq 'DESTROY');

    my $obj = {
        id     => 1,
        method => $method,
        params => (ref $_[0] ? $_[0] : [@_]),
    };

    $self->add_child(my $client = Net::Async::WebSocket::Client->new());

    $client->{framebuffer} = Protocol::WebSocket::Frame->new(max_payload_size => 0);
    $client->configure(
        on_text_frame => sub {
            my ($s, $frame) = @_;
            $self->source->emit(decode_json_utf8($frame));
        },
    );

    $client->connect(url => $self->endpoint)->on_done(sub {
        $client->send_text_frame(encode_json_utf8($obj));
    })->on_fail(sub{
        die "Can't not connect to the websocket endpoint: @{[$self->endpoint]}";
    })->get;

    return $self->source;
}

1;

