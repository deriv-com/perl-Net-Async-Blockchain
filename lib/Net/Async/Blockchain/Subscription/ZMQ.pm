package Net::Async::Blockchain::Subscription::ZMQ;

use strict;
use warnings;
no indirect;

use Moo;
use ZMQ::LibZMQ3;
use ZMQ::Constants qw(ZMQ_RCVMORE ZMQ_SUB ZMQ_SUBSCRIBE ZMQ_RCVHWM ZMQ_FD);

use IO::Async::Loop;
use IO::Async::Notifier;
use IO::Async::Handle;
use Ryu::Async;

extends 'IO::Async::Notifier';

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
    push @multipart, zmq_recvmsg($socket);

    while (zmq_getsockopt($socket, ZMQ_RCVMORE)) {
        push @multipart, zmq_recvmsg($socket);
    }

    return @multipart;
}

1;

