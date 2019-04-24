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

    $client->eth_subscribe('newHeads')->each(sub {print shift->{hash}});

    $loop->run();

=head1 DESCRIPTION

Auto load the commands as the method parameters for the websocket calls returning them asynchronously.

=over 4

=back

=cut

no indirect;

use JSON::MaybeUTF8 qw(encode_json_utf8 decode_json_utf8);

use Net::Async::WebSocket::Client;

use parent qw(IO::Async::Notifier);

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
        $self->{source} = $ryu->source;
        return $self->{source};
        }
}

=head2 endpoint

Websocket endpoint

=over 4

=back

URL containing the port if needed

=cut

sub endpoint : method { shift->{endpoint} }

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

=head2 AUTOLOAD

Use any argument as the method parameter for the websocket client call

=over 4

=item * C<method>

=item * C<@_> - any parameter required by the RPC call

=back

=cut

sub AUTOLOAD {
    my ($self, @params) = @_;

    my $method = $Net::Async::Blockchain::Client::Websocket::AUTOLOAD;
    $method =~ s/.*:://;

    return if ($method eq 'DESTROY');

    my $obj = {
        id     => 1,
        method => $method,
        params => [@params]};

    $self->add_child(my $client = Net::Async::WebSocket::Client->new());

    $client->{framebuffer} = Protocol::WebSocket::Frame->new(max_payload_size => 0);
    $client->configure(
        on_text_frame => sub {
            my (undef, $frame) = @_;
            $self->source->emit(decode_json_utf8($frame));
        },
    );

    $client->connect(url => $self->endpoint)->on_done(
        sub {
            $client->send_text_frame(encode_json_utf8($obj));
        }
        )->on_fail(
        sub {
            die "Can't connect to the websocket endpoint: @{[$self->endpoint]}";
        })->get;

    return $self->source;
}

1;

