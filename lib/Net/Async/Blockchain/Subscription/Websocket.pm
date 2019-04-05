package Net::Async::Blockchain::Subscription::Websocket;

use strict;
use warnings;

our $VERSION = '0.001';

=head1 NAME

Net::Async::Blockchain::Client::RPC - Async RPC Client.

=head1 SYNOPSIS

    my $loop = IO::Async::Loop->new();

    $loop->add(my $ws_source = Ryu::Async->new());

    $loop->add(
        my $client = Net::Async::Blockchain::Subscription::Websocket->new(
            endpoint => $self->config->{subscription_url},
            source => $ws_source->source,
        );
    );

    my $response = $client->getblockchaininfo()->take(1)->as_list;

    print $response[0]->{blocks};

    $loop->run();

=head1 DESCRIPTION

Auto load the commands as the method parameters for the RPC calls returning them asynchronously.

=over 4

=cut

no indirect;

use JSON::MaybeUTF8 qw(encode_json_utf8 decode_json_utf8);

use Net::Async::WebSocket::Client;

use base qw(IO::Async::Notifier);

sub source : method { shift->{source} }

sub endpoint : method { shift->{endpoint} }

=head2 _init

Called by `new` before `configure`, any additional configuration
that is not described on IO::ASYNC::Notifier must be included and
removed here.

=over 4

=item * C<rpc_url>

=item * C<rpc_timeout>

=back

=cut

sub _init {
    my ($self, $paramref) = @_;
    $self->SUPER::_init;

    for my $k (qw(endpoint source)) {
        $self->{$k} = delete $paramref->{$k} if exists $paramref->{$k};
    }

}

=head2 AUTOLOAD

Use any argument as the method parameter for the websocket client call

=over 4

=item * C<method>

=item * C<params> (any parameter required by the RPC call)

=back

=cut

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
        die "Can't connect to the websocket endpoint: @{[$self->endpoint]}";
    })->get;

    return $self->source;
}

1;

