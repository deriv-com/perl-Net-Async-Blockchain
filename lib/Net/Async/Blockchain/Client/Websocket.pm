package Net::Async::Blockchain::Client::Websocket;

use strict;
use warnings;

our $VERSION = '0.001';

=head1 NAME

Net::Async::Blockchain::Client::Websocket - Async websocket Client.

=head1 SYNOPSIS

Objects of this type would not normally be constructed directly.

=head1 DESCRIPTION

Auto load the commands as the method parameters for the websocket calls returning them asynchronously.

=over 4

=back

=cut

no indirect;

use JSON::MaybeUTF8 qw(decode_json_utf8);
use Protocol::WebSocket::Frame;
use Ryu::Async;

use Net::Async::WebSocket::Client;

use parent qw(IO::Async::Notifier);

=head2 latest_subscription

Latest subscription sent from this module

=cut

sub latest_subscription : method { shift->{latest_subscription} }

=head2 timer

L<IO::Async::Timer::Periodic> object, it will send periodic frames to keep the connection alive
if needed, if not needed just leave it as undef.

=cut

sub timer : method { shift->{timer} }

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
                    warn "Connection closed by peer, trying reconnetion";
                    # when the connection is closed by the peer we need
                    # to reconnect to keep receiving the subscription info.
                    $self->timer->stop() if $self->timer;
                    $self->{websocket_client} = undef;
                    $self->subscribe($self->latest_subscription);
                },
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

=head2 subscribe

Subscribe to an event

=over 4

=item * C<method>

=item * C<@_> - any parameter required by the RPC call

=back

=cut

sub subscribe {
    die 'Not implemented';
}

1;

