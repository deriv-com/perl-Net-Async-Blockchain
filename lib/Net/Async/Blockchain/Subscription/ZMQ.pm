package Net::Async::Blockchain::Subscription::ZMQ;

use strict;
use warnings;
no indirect;

our $VERSION = '0.001';

use ZMQ::LibZMQ3;
use ZMQ::Constants qw(ZMQ_RCVMORE ZMQ_SUB ZMQ_SUBSCRIBE ZMQ_RCVHWM ZMQ_FD);

use IO::Async::Loop;
use IO::Async::Notifier;
use IO::Async::Handle;
use Ryu::Async;

my $loop = IO::Async::Loop->new;
# $loop->add(my $ryu = Ryu::Async->new);

use constant SUBSCRIPTIONS => [qw(hashblock hashtx rawblock rawtx)];

sub subscribe {
    my ($endpoint, $subscription, $callback) = @_;

    return unless is_valid_subscription($subscription);

    my $ctxt = zmq_init(1);
    my $socket = zmq_socket($ctxt, ZMQ_SUB);

    zmq_setsockopt($socket, ZMQ_RCVHWM, 0);
    ZMQ::LibZMQ3::zmq_setsockopt_string($socket, ZMQ_SUBSCRIBE, $subscription);
    zmq_connect($socket, $endpoint);

    my $fd = zmq_getsockopt($socket, ZMQ_FD);
    open(my $io, "<&", $fd);

    my $notifier = IO::Async::Notifier->new;
    $notifier->add_child(
        my $handle = IO::Async::Handle->new(
        read_handle => $io,
        on_read_ready  => sub {
            while (my @msg = _recv_multipart($socket)) {
                my $hex = unpack('H*', zmq_msg_data($msg[1]));
                $callback->($hex);
                # $ryu->source->emit($hex);
            }
        },)
    );

    $loop->add($notifier);
    # return $ryu->source;
    return 1;
}

sub is_valid_subscription {
    my ($subscription) = @_;
    return grep {$subscription && $_ eq $subscription} @{+SUBSCRIPTIONS};
}

sub _recv_multipart {
    my ($socket) = @_;

    my @multipart;
    push @multipart, zmq_recvmsg($socket);

    while (zmq_getsockopt($socket, ZMQ_RCVMORE)) {
        push @multipart, zmq_recvmsg($socket);
    }

    return @multipart;
}

1;

