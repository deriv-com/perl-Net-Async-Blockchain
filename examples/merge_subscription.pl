#!/usr/bin/env perl

use strict;
use warnings;
no indirect;

use IO::Async::Loop;
use Data::Dumper;

use Net::Async::Blockchain::BTC;
use Net::Async::Blockchain::ETH;

my $btc_args = { subscription_url => "tcp://127.0.0.1:28332", rpc_url => 'http://test:test@127.0.0.1:8332' };
my $eth_args = { subscription_url => "wss://rinkeby.infura.io/ws/v3/c56fba38337b4e2ea552e42529641896" };

my $loop = IO::Async::Loop->new;

$loop->add(
    my $eth_client = Net::Async::Blockchain::ETH->new(
        config => $eth_args
    )
);
$loop->add(
    my $btc_client = Net::Async::Blockchain::BTC->new(
        config => $btc_args
    )
);

$btc_client->subscribe("rawtx")->merge($eth_client->subscribe("newHeads"))->each(sub { print Dumper shift });

$loop->run();

