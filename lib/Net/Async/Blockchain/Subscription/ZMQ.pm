package Net::Async::Blockchain::Subscription::ZMQ;

use strict;
use warnings;
no indirect;

use ZMQ::LibZMQ3;
use ZMQ::Constants qw(ZMQ_RCVMORE ZMQ_SUB ZMQ_SUBSCRIBE ZMQ_RCVHWM ZMQ_FD ZMQ_DONTWAIT);

use IO::Async::Notifier;
use IO::Async::Handle;

use parent qw(IO::Async::Notifier);

sub source : method { shift->{source} }

sub endpoint : method { shift->{endpoint} }

sub _init {
    my ($self, $paramref) = @_;
    $self->SUPER::_init;

    for my $k (qw(endpoint source)) {
        $self->{$k} = delete $paramref->{$k} if exists $paramref->{$k};
    }
}

sub subscribe {
    my ($self, $subscription) = @_;

    my $ctxt = zmq_init(1);
    my $socket = zmq_socket($ctxt, ZMQ_SUB);

    zmq_setsockopt($socket, ZMQ_RCVHWM, 0);
    ZMQ::LibZMQ3::zmq_setsockopt_string($socket, ZMQ_SUBSCRIBE, $subscription);
    zmq_connect($socket, $self->endpoint);

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
        ));

    return $self->source;
}

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

