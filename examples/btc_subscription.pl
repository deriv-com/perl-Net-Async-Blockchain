#!/usr/bin/env perl

use strict;
use warnings;
no indirect;

use IO::Async::Loop;
use Data::Dumper;

use Net::Async::Blockchain::BTC;

my $btc_args = { subscription_url => "tcp://127.0.0.1:28332", rpc_url => 'http://test:test@127.0.0.1:8332' };

my $loop = IO::Async::Loop->new;

$loop->add(
    my $btc_client = Net::Async::Blockchain::BTC->new(
        config => $btc_args
    )
);

$btc_client->subscribe("rawtx")->each(sub { print Dumper shift });

$loop->run();
