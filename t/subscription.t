#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;
use Net::Async::Blockchain::Client;

my $client = Net::Async::Blockchain::Client->new('BTC');
my $args         = {
    host              => "127.0.0.1",
    port              => 8332,
    subscription_port => 28332,
    user              => "test",
    password          => "test"
};

if ($client->configure($args)) {
    $client->subscribe("rawtx")->each(sub { diag explain shift })->get;
}

done_testing;
