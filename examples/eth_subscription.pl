#!/usr/bin/env perl

use strict;
use warnings;
no indirect;

use IO::Async::Loop;
use Data::Dumper;

use Net::Async::Blockchain::ETH;

my $eth_args = { subscription_url => "wss://rinkeby.infura.io/ws/v3/c56fba38337b4e2ea552e42529641896" };

my $loop = IO::Async::Loop->new;

$loop->add(
    my $eth_client = Net::Async::Blockchain::ETH->new(
        config => $eth_args
    )
);

$eth_client->subscribe("newHeads")->each(sub { print Dumper shift });

$loop->run();

