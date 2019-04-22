#!/usr/bin/env perl

use strict;
use warnings;
no warnings 'redefine';

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

my $peersock;
local *IO::Async::Handle::connect = sub {
    my $self = shift;

    (my $selfsock, $peersock) = IO::Async::OS->socketpair() or die "Cannot create socket pair - $!";
    $self->set_handle($selfsock);

    return Future->new->done($self);
};

my $loop = IO::Async::Loop->new();
testing_loop($loop);

subtest 'stall timeout' => sub {
    $loop->add(
        my $rpc = Net::Async::Blockchain::Client::RPC->new(
            endpoint => "http://abcd.com",
            timeout  => 0.1,
        ));

    like(exception { $rpc->eth_blockNumber->get() }, qr(Stalled while waiting for response), 'Stall timeout');
};

subtest 'no endpoint' => sub {
    $loop->add(my $rpc = Net::Async::Blockchain::Client::RPC->new());

    like(exception { $rpc->eth_blockNumber->get() }, qr(Require either 'uri' or 'request'), 'No endpoint');
};

done_testing;

