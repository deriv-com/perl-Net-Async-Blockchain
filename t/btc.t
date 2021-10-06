#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::MockModule;
use Test::Exception;
use Test::TCP;

use Future::AsyncAwait;
use IO::Async::Loop;
use ZMQ::LibZMQ3;
use ZMQ::Constants qw(:all);

use Net::Async::Blockchain::BTC;

my $mock_rpc = Test::MockModule->new("Net::Async::Blockchain::Client::RPC::BTC");
my $mock_btc = Test::MockModule->new("Net::Async::Blockchain::BTC");

my $loop = IO::Async::Loop->new();

subtest "subscribe _ wrong subscription type" => sub {

    $loop->add(my $blockchain_btc = Net::Async::Blockchain::BTC->new());
    dies_ok { $blockchain_btc->subscribe('dummy') } 'expecting to die due to wrong subscription type';
};

subtest "subscribe" => sub {

    # ZMQ server
    my $block_hash_bytes = pack('H*', '00000000a4bceeac7fd4a65e71447724e5e67e9d8d0d5a7e6906776eaa35e834');
    my @msg              = ('hashblock', $block_hash_bytes);
    my $zmq_server       = Test::TCP->new(
        code => sub {
            my $port = shift;
            my $ctxt = zmq_init();
            my $sock = zmq_socket($ctxt, ZMQ_PUB);

            zmq_bind($sock, "tcp://127.0.0.1:$port");
            sleep 2;
            for (@msg) {
                zmq_sendmsg($sock, zmq_msg_init_data($_), ZMQ_SNDMORE);
            }
            zmq_sendmsg($sock, zmq_msg_init_data("last"), 0);
            exit 0;
        });

    my $port = $zmq_server->port;
    my $ctxt = zmq_init();
    my $sock = zmq_socket($ctxt, ZMQ_SUB);

    $loop->add(my $blockchain_btc = Net::Async::Blockchain::BTC->new(subscription_url => "tcp://127.0.0.1:$port"));

    $mock_btc->mock(
        recursive_search => async sub {
            return undef;
        });

    $mock_rpc->mock(
        get_block => async sub {
            return $get_block_value;
        },
        get_transaction => async sub {
            return $get_transaction_value;
        });

    my $btc_subscribe = $blockchain_btc->subscribe('transactions');
    is ref $btc_subscribe, 'Ryu::Source', 'correct reference for Ryu Source';

    $btc_subscribe->each(
        sub {
            my $emitted_transaction = shift;
            is_deeply $emitted_transaction, $expected_transaction, "Correct emitted trasnaction";
            $btc_subscribe->finish();
        })->get;

    zmq_close($blockchain_btc->zmq_client->socket_client());
    $mock_rpc->unmock_all();
    $mock_btc->unmock_all();
};

done_testing;
