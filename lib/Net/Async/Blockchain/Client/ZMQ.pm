package Net::Async::Blockchain::Client::ZMQ;

use strict;
use warnings;

our $VERSION = '0.001';

=head1 NAME

Net::Async::Blockchain::Client::ZMQ - Async ZMQ Client.

=head1 SYNOPSIS

    my $loop = IO::Async::Loop->new();

    $loop->add(my $zmq_source = Ryu::Async->new);

    $loop->add(
        my $zmq_client = Net::Async::Blockchain::Client::ZMQ->new(
            source   => $zmq_source->source,
            endpoint => 'tpc://127.0.0.1:28332',
        ));

    $zmq_client->subscribe('rawtx')->each(sub{print shift->{hash}});

    $loop->run();

=head1 DESCRIPTION

client for the bitcoin ZMQ server

=over 4

=back

=cut

no indirect;
use autodie qw(open close);

use ZMQ::LibZMQ3;
use ZMQ::Constants qw(ZMQ_RCVMORE ZMQ_SUB ZMQ_SUBSCRIBE ZMQ_RCVHWM ZMQ_FD ZMQ_DONTWAIT);

use IO::Async::Notifier;
use IO::Async::Handle;
use Socket;

use parent qw(IO::Async::Notifier);

sub source : method { shift->{source} }

sub endpoint : method { shift->{endpoint} }

=head2 configure

Any additional configuration that is not described on L<IO::ASYNC::Notifier>
must be included and removed here.

If this class receive a DNS as endpoint this will be resolved on this method
to an IP address.

=over 4

=item * C<endpoint>

=item * C<source> L<Ryu::Source>

=back

=cut

sub configure {
    my ($self, %params) = @_;

    for my $k (qw(endpoint source)) {
        $self->{$k} = delete $params{$k} if exists $params{$k};
    }

    my $uri  = URI->new($self->endpoint);
    my $host = $uri->host;

    # Resolve DNS if needed
    if ($host !~ /(\d+(\.|$)){4}/) {
        my @addresses = gethostbyname($host) or die "Can't resolve @{[$host]}: $!";
        @addresses = map { inet_ntoa($_) } @addresses[4 .. $#addresses];

        my $address = $addresses[0];

        $self->{endpoint} = $self->{endpoint} =~ s/$host/$address/r;
    }

    $self->SUPER::configure(%params);
}

=head2 subscribe

Connect to the ZMQ server and start the subscription

=over 4

=item * C<subscription> subscription string name

=back

L<Ryu::Source>

=cut

sub subscribe {
    my ($self, $subscription) = @_;

    my $ctxt = zmq_ctx_new(1);
    die "zmq_ctc_new failed with $!" unless $ctxt;

    my $socket = zmq_socket($ctxt, ZMQ_SUB);

    # zmq_setsockopt_string is not exported
    ZMQ::LibZMQ3::zmq_setsockopt_string($socket, ZMQ_SUBSCRIBE, $subscription);

    my $connect_response = zmq_connect($socket, $self->endpoint);
    die "zmq_connect failed with $!" if $connect_response;

    # create a reader for IO::Async::Handle using the ZMQ socket file descriptor
    my $fd = zmq_getsockopt($socket, ZMQ_FD);
    open(my $io, "<&", $fd);

    $self->add_child(
        my $handle = IO::Async::Handle->new(
            read_handle   => $io,
            on_read_ready => sub {
                while (my @msg = $self->_recv_multipart($socket)) {
                    my $hex = unpack('H*', zmq_msg_data($msg[1]));
                    $self->source->emit($hex);
                }
            },
            on_closed => sub {
                close($io);
            }
        ));

    return $self->source;
}

=head2 _recv_multipart

Since each response is partial we need to join them

=over 4

=item * C<subscription> subscription string name

=back

Multipart response array

=cut

sub _recv_multipart {
    my ($self, $socket) = @_;

    my @multipart;

    push @multipart, zmq_recvmsg($socket, ZMQ_DONTWAIT);
    while (zmq_getsockopt($socket, ZMQ_RCVMORE)) {
        push @multipart, zmq_recvmsg($socket, ZMQ_DONTWAIT);
    }

    return @multipart;
}

1;

