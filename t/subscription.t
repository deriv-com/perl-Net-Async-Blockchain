#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;
use Net::Async::Blockchain::Client;

# my $args = { subscription_url => "tcp://127.0.0.1:28332", rpc_url => 'http://test:test@127.0.0.1:8332' };

# my $client = Net::Async::Blockchain::Client->new('BTC', $args);
# $client->subscribe("rawtx")->each(sub { diag explain shift })->get;

my $args = { subscription_url => "wss://mainnet.infura.io/ws/v3/" };

my $client = Net::Async::Blockchain::Client->new('ETH', $args);
$client->subscribe("newHeads")->each(sub { diag explain shift })->get;

done_testing;
