package Net::Async::Blockchain::Client::Websocket::ETH;

use strict;
use warnings;
no indirect;

our $VERSION = '0.001';

=head1 NAME

Net::Async::Blockchain::Client::Websocket::ETH - Async websocket Client for ETH based nodes.

=head1 SYNOPSIS

    my $loop = IO::Async::Loop->new();

    $loop->add(my $ws_source = Ryu::Async->new());

    $loop->add(
        my $client = Net::Async::Blockchain::Client::Websocket::ETH->new(
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
use JSON::MaybeUTF8 qw(encode_json_utf8);
use Protocol::WebSocket::Request;
use IO::Async::Timer::Periodic;

use Net::Async::WebSocket::Client;

use parent qw(Net::Async::Blockchain::Client::Websocket);

use constant {
    KEEP_ALIVE                           => 5,
    RECONNECTION_DELAY_WHEN_NODE_IS_DOWN => 10,
};

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
    $self->{timer} = IO::Async::Timer::Periodic->new(
        interval => KEEP_ALIVE,
        on_tick  => sub {
            $self->websocket_client->send_text_frame(encode_json_utf8($timer_call));
        },
    );

    $self->add_child($self->timer);

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
            $self->timer->start();
        }
        )->on_fail(
        sub {
            warn "Failing to connect to the node, reconnection will be delayed by @{[RECONNECTION_DELAY_WHEN_NODE_IS_DOWN]} seconds";
            $self->reconnect(RECONNECTION_DELAY_WHEN_NODE_IS_DOWN);
        })->retain();

    return $self->source;
}

=head2 subscribe

Subscribe to an event

=over 4

=item * C<method>

=item * C<@_> - any parameter required by the RPC call

=back

=cut

sub subscribe {
    my ($self, $subscription) = @_;
    $self->{latest_subscription} = $subscription;
    return $self->_request('eth_subscribe', $subscription);
}

1;

