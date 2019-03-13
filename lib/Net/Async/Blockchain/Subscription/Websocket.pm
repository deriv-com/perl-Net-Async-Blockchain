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

    $self->connect(url => $self->endpoint)->then(sub {
            $self->send_text_frame(encode_json_utf8($obj));
        })->get;

    return $self->source;
}

1;

