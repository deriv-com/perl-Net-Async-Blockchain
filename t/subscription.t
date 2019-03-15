#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;
use Net::Async::Blockchain;

my $btc_args = { subscription_url => "tcp://127.0.0.1:28332", rpc_url => 'http://test:test@127.0.0.1:8332' };
my $eth_args = { subscription_url => "wss://mainnet.infura.io/ws/v3/c56fba38337b4e2ea552e42529641896" };

my $btc_client = Net::Async::Blockchain->new('BTC', $btc_args);
my $eth_client = Net::Async::Blockchain->new('ETH', $eth_args);

# $eth_client->subscribe("newHeads")->each(sub {diag explain shift})->get;
$btc_client->subscribe("rawtx")->each(sub { diag explain shift })->get;

# $eth_client->subscribe("newHeads")->merge($btc_client->subscribe("rawtx"))->each(sub {diag explain shift})->get;

done_testing;
