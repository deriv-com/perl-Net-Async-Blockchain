#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;
use Test::MockModule;
use IO::Async::Test;
use IO::Async::Loop;
use JSON::MaybeUTF8 qw(encode_json_utf8 decode_json_utf8);
use HTTP::Request;

BEGIN {
    use_ok "Net::Async::HTTP";
    use_ok "Net::Async::Blockchain::Client::RPC";
}

my $loop = IO::Async::Loop->new();
testing_loop($loop);

$loop->add(
    my $rpc = Net::Async::Blockchain::Client::RPC->new(
        endpoint => "http://127.0.0.1:8332",
        timeout  => 10,
    ));

my $mock_http = Test::MockModule->new('Net::Async::HTTP');
$mock_http->mock(
    POST => sub {
        my ($s, $host, $content) = @_;
        my $decoded = decode_json_utf8($content);
        ok $decoded, "valid json request";
        my $response = HTTP::Message->new(undef, encode_json_utf8({result => $decoded}));
        return Future->done($response);
    });

is $rpc->eth_blockNumber->get()->{method}, "eth_blockNumber", "valid request";

done_testing;

