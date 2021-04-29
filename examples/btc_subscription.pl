#!/usr/bin/env perl

use strict;
use warnings;
no indirect;

use IO::Async::Loop;
use Data::Dumper;

use Net::Async::Blockchain::BTC;

my $loop = IO::Async::Loop->new;

$loop->add(
    my $btc_client = Net::Async::Blockchain::BTC->new(
        subscription_url => 'tcp://crypto-node-qa-buster.regentmarkets.com:28332',
        rpc_url          => 'http://crypto-node-qa-buster.regentmarkets.com:8332',
        rpc_user         => 'qabtc',
        rpc_password     => 'ChinOwgexSoatNetAkovjubty',
        # Timeout time for connection (seconds)
        subscription_timeout => 100,
        # Timeout time for received messages, this is applied when we have a bigger
        # duration interval between the messages (seconds).
        subscription_msg_timeout => 3600,
        # Timeout time for connection (seconds)
        rpc_timeout => 100,
        # block number to search from when start
        base_block_number => 1973110,
    ));

$btc_client->subscribe("transactions")->each(sub { print Dumper shift} )->get;
