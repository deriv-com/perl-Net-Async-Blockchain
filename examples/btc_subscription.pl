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
        subscription_url         => "tcp://127.0.0.1:28332",
        rpc_url                  => 'http://test:test@127.0.0.1:8332',
        subscription_timeout     => 100,
        subscription_msg_timeout => 3600000,
        rpc_timeout              => 100,
        lookup_transactions      => 10,
    ));

$btc_client->subscribe("transactions")->each(sub { print Dumper shift });

$loop->run();
