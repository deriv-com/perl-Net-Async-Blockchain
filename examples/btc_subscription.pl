#!/usr/bin/env perl

use strict;
use warnings;
no indirect;

use IO::Async::Loop;
use Data::Dumper;
use Future::AsyncAwait;

use Net::Async::Blockchain::BTC;

my $loop = IO::Async::Loop->new;

$loop->add(
    my $btc_client = Net::Async::Blockchain::BTC->new(
        subscription_url => 'tcp://127.0.0.1:28332',
        rpc_url          => 'http://127.0.0.1:8332',
        rpc_user         => 'test',
        rpc_password     => 'test',
        # Timeout time for connection (seconds)
        subscription_timeout => 3600,
        # Timeout time for received messages, this is applied when we have a bigger
        # duration interval between the messages (seconds).
        subscription_msg_timeout => 3600,
        # Timeout time for connection (seconds)
        rpc_timeout => 100,
    ));

async sub run {
    await $btc_client->recursive_search(1973943);
    await $btc_client->subscribe("transactions")->each(sub { print Dumper shift })->completed;
}

run()->get;
