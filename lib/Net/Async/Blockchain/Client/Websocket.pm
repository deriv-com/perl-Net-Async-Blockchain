package Net::Async::Blockchain::Client::Websocket;

use strict;
use warnings;

our $VERSION = '0.001';

=head1 NAME

Net::Async::Blockchain::Client::Websocket - Async websocket Client.

=head1 SYNOPSIS

    my $loop = IO::Async::Loop->new();

    $loop->add(my $ws_source = Ryu::Async->new());

    $loop->add(
        my $client = Net::Async::Blockchain::Client::Websocket->new(
            endpoint => "ws://127.0.0.1:8546",
        )
    );

    $client->eth_subscribe('newHeads')->each(sub {print shift->{hash}})->get;

=head1 DESCRIPTION

Auto load the commands as the method parameters for the websocket calls returning them asynchronously.

=over 4

=back

=cut

no indirect;

use URI;
use JSON::MaybeUTF8 qw(encode_json_utf8 decode_json_utf8);
use Protocol::WebSocket::Request;

use Net::Async::WebSocket::Client;

use parent qw(IO::Async::Notifier);

use constant KEEP_ALIVE => 5;

=head2 source

Create an L<Ryu::Source> instance, if it is already defined just return
the object

=over 4

=back

L<Ryu::Source>

=cut

sub source : method {
    my ($self) = @_;
    return $self->{source} //= do {
        $self->add_child(my $ryu = Ryu::Async->new);
        $ryu->source;
    };
}

=head2 endpoint

Websocket endpoint

=over 4

=back

URL containing the port if needed

=cut

sub endpoint : method { shift->{endpoint} }

=head2 websocket_client

Create an L<Net::Async::WebSocket::Client> instance, if it is already defined just return
the object

=over 4

=back

L<Net::Async::WebSocket::Client>

=cut

sub websocket_client : method {
    my ($self) = @_;

    return $self->{websocket_client} //= do {
        $self->add_child(
            my $client = Net::Async::WebSocket::Client->new(
                on_text_frame => sub {
                    my (undef, $frame) = @_;
                    $self->source->emit(decode_json_utf8($frame));
                },
                on_closed => sub {
                    die "Connection closed by peer";
                },
                close_on_read_eof => 1,
            ));

        $client->{framebuffer} = Protocol::WebSocket::Frame->new(max_payload_size => 0);
        $client;
    };
}

=head2 configure

Any additional configuration that is not described on L<IO::Async::Notifier>
must be included and removed here.

=over 4

=item * C<endpoint>

=back

=cut

sub configure {
    my ($self, %params) = @_;

    for my $k (qw(endpoint)) {
        $self->{$k} = delete $params{$k} if exists $params{$k};
    }

    $self->SUPER::configure(%params);
}

=head2 _request

Prepare the data to be sent to the websocket and call the request

=over 4

=item * C<method>

=item * C<@_> - any parameter required by the RPC call

=back

L<Ryu::Source>

=cut

sub _request {
    my ($self, $method, @params) = @_;

    my $url = URI->new($self->endpoint);

    # this is a simple block number request
    my $timer_call = {
        id     => 1,
        method => 'eth_blockNumber',
        params => []};

    # we need to keep sending requests to the node
    # otherwise after some period of time we just
    # get disconnected by the peer, 5 seconds is enough
    # to keep the connection alive.
    my $timer = IO::Async::Timer::Periodic->new(
        interval => KEEP_ALIVE,
        on_tick  => sub {
            $self->websocket_client->send_text_frame(encode_json_utf8($timer_call));
        },
    );

    $self->add_child($timer);

    # this is the client request
    my $request_call = {
        id     => 1,
        method => $method,
        params => [@params]};

    $self->websocket_client->connect(
        url => $self->endpoint,
        req => Protocol::WebSocket::Request->new(origin => $url->host),
        )->then(
        sub {
            return $self->websocket_client->send_text_frame(encode_json_utf8($request_call));
        }
        )->on_done(
        sub {
            $timer->start();
        })->retain();

    return $self->source;
}

=head2 eth_subscribe

Subscribe to an event

=over 4

=item * C<method>

=item * C<@_> - any parameter required by the RPC call

=back

=cut

sub eth_subscribe {
    my ($self, $subscription) = @_;
    return $self->_request('eth_subscribe', $subscription);
}

1;

