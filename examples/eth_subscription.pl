#!/usr/bin/env perl

use strict;
use warnings;
no indirect;

use IO::Async::Loop;
use Data::Dumper;

use Net::Async::Blockchain::ETH;

my $eth_args = { subscription_url => "ws://127.0.0.1:8546", rpc_url => "http://127.0.0.1:8545" };

my $loop = IO::Async::Loop->new;

$loop->add(
    my $eth_client = Net::Async::Blockchain::ETH->new(
        config => $eth_args
    )
);

$eth_client->subscribe("newHeads")->each(sub { print Dumper shift });

$loop->run();

