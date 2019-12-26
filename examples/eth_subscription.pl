#!/usr/bin/env perl

use strict;
use warnings;
no indirect;

use IO::Async::Loop;
use Data::Dumper;

use Net::Async::Blockchain::ETH;

my $loop = IO::Async::Loop->new;

$loop->add(
    my $eth_client = Net::Async::Blockchain::ETH->new(
        subscription_url => "ws://127.0.0.1:8546",
        rpc_url          => "http://127.0.0.1:8545",
    ));

$eth_client->subscribe("transactions")->each(sub { print Dumper shift })->get();

