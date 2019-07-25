#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;
use IO::Socket::IP;
use IO::Async::Test;
use IO::Async::Loop;
use Net::Async::WebSocket::Server;
use Net::Async::Blockchain::Client::Websocket::ETH;
use JSON::MaybeUTF8 qw(encode_json_utf8 decode_json_utf8);

my $loop = IO::Async::Loop->new;
testing_loop($loop);

my $serversock = IO::Socket::IP->new(
    LocalHost => "127.0.0.1",
    Listen    => 1,
) or die "Cannot allocate listening socket - $@";

my @serverframes;
my $reconnections = 0;

my $server = Net::Async::WebSocket::Server->new(
    handle => $serversock,

    on_client => sub {
        my (undef, $client) = @_;

        $reconnections += 1;

        $client->configure(
            on_text_frame => sub {
                my ($self, $frame) = @_;
                push @serverframes, $frame;
            },
        );
    },
);

$loop->add($server);

my @clientframes;
my $host    = $serversock->sockhost;
my $service = $serversock->sockport;

my $ws_client = Net::Async::Blockchain::Client::Websocket::ETH->new(
    endpoint => sprintf("ws://%s:%s", $host, $service),
);

$loop->add($ws_client);

$ws_client->subscribe('newHeads');

wait_for { @serverframes };

is_deeply(decode_json_utf8(shift(@serverframes))->{params}, ["newHeads"], 'received subscription');

wait_for { @serverframes };

is_deeply(decode_json_utf8(shift(@serverframes))->{method}, "eth_blockNumber", 'received keep alive timer response');

$ws_client->websocket_client->close();

wait_for { @serverframes };

is_deeply(decode_json_utf8(shift(@serverframes))->{method}, "eth_subscribe", 'trying to subscribe after failure');

is $reconnections, 2, "reconnecting ok";

done_testing;