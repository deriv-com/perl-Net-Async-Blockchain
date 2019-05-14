#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;
use Test::TCP;
use IO::Async::Test;
use IO::Async::Loop;
use Ryu::Async;

BEGIN {
    use_ok "ZMQ::LibZMQ3";
    use_ok "ZMQ::Constants", ":v3.1.1", ":all";
    use_ok "Net::Async::Blockchain::Client::ZMQ";
}

subtest 'receive msg' => sub {
    my @msg = (7261777478, "{hash => Test_Transaction}", 92870000);
    my $server = Test::TCP->new(
        code => sub {
            my $port = shift;
            my $ctxt = zmq_init();
            my $sock = zmq_socket($ctxt, ZMQ_PUB);

            zmq_bind($sock, "tcp://127.0.0.1:$port");
            sleep 2;
            for my $i (0 .. 9) {
                for (@msg) {
                    zmq_sendmsg($sock, zmq_msg_init_data($_), ZMQ_SNDMORE);
                }
                zmq_sendmsg($sock, zmq_msg_init_data("last"), 0);
            }
            exit 0;
        });

    my $port = $server->port;
    my $ctxt = zmq_init();
    my $sock = zmq_socket($ctxt, ZMQ_SUB);

    my $loop = IO::Async::Loop->new();
    testing_loop($loop);

    $loop->add(my $zmq_source = Ryu::Async->new);
    $loop->add(
        my $zmq_client = Net::Async::Blockchain::Client::ZMQ->new(
            endpoint => "tcp://127.0.0.1:$port",
        ));

    $zmq_client->subscribe('')->take(10)->each(
        sub {
            is shift, unpack("H*", $msg[1]), "Correct message received";
        })->get;
};

done_testing;
