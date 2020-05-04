#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;
use Test::MockModule;
use Test::MemoryGrowth;
use Net::Async::Blockchain::Omni;
use Net::Async::WebSocket::Server;
use JSON::MaybeUTF8 qw(decode_json_utf8);
use Future::AsyncAwait;

my $loop = IO::Async::Loop->new;
$loop->add(
    my $omni_client = Net::Async::Blockchain::Omni->new(
        subscription_url => "ws://127.0.0.1:28700",
        rpc_url          => "http://127.0.0.1:8700",
    ));

my $mocked_rpc_omni = Test::MockModule->new('Net::Async::Blockchain::Client::RPC::Omni');
my $mocked_omni     = Test::MockModule->new('Net::Async::Blockchain::Omni');

my $from = 'mgVxUb5mYJkfoo4w2JBVBcWaP5bqtLroTr';
my $to   = '2N42Xmf1xBCr4f4ofLprCRfzAYp61K9tWgU';

$mocked_rpc_omni->mock(
    'get_transaction' => sub {
        my ($self, $tx) = @_;
        my $omni_gettransaction;
        if ($tx eq 'a1ee54bc8f517794ee88d45a2843720654a4ac18adbe44968de8372cf7faa617') {
            $omni_gettransaction = {
                blocktime        => 1582105648,
                confirmations    => 1,
                blockhash        => '0000000023563d72e89c7e185d90e153739667b413ee0b99c83002b941da8663',
                block            => 1666225,
                type             => 'Simple Send',
                amount           => '12.00000000',
                fee              => '0.00000254',
                positioninblock  => 687,
                sendingaddress   => $from,
                ismine           => 1,
                txid             => 'a1ee54bc8f517794ee88d45a2843720654a4ac18adbe44968de8372cf7faa617',
                type_int         => 0,
                referenceaddress => $to,
                propertyid       => 2147484941,
                version          => 0,
                valid            => 1
            };
        } else {
            $omni_gettransaction = {
                blocktime        => 1582103231,
                confirmations    => 1,
                blockhash        => '000000000005a678d87340aa0e21704eb5d0673d442a7ab0725bd169dff76897',
                block            => 1666223,
                type             => 'Simple Send',
                amount           => '0.00100000',
                fee              => '0.00000985',
                positioninblock  => 75,
                sendingaddress   => $from,
                ismine           => 1,
                txid             => 'dc1f7ab5db70c37c8dda87249d16e933eec1583a7a03b1d9a98166bef2661faf',
                type_int         => 0,
                referenceaddress => $to,
                propertyid       => 2147484941,
                version          => 0,
                valid            => 0,
                invalidreason    => 'Sender has insufficient balance'
            };

        }

        return Future->done($omni_gettransaction);
    },
    'list_by_addresses' => sub {
        my ($self, $address) = @_;
        my $result;

        if ($address eq $from || $address eq $to) {
            $result = [{address => $from}, {address => $to}];
        }

        else { $result = []; }

        return Future->done($result);
    });

$mocked_omni->mock(
    'mapping_address' => sub {
        my ($self, $omni_transaction) = @_;
        my ($from_detail, $to_detail);

        $from_detail->{address} = $from;
        $to_detail->{address}   = $to;

        return Future->done(($from_detail, $to_detail));
    });

subtest "Omni memory test" => sub {
    no_growth {
        $omni_client->transform_transaction(
            decode_json_utf8(
                '{"jsonrpc":"2.0","id":1,"result":{ "txid":"a1ee54bc8f517794ee88d45a2843720654a4ac18adbe44968de8372cf7faa617","hash":"a1ee54bc8f517794ee88d45a2843720654a4ac18adbe44968de8372cf7faa617","block":"1666225"}}'
            )->{result});
    }
    'Subscription for Omni no memory growth for valid transaction';
    no_growth {
        $omni_client->transform_transaction(
            decode_json_utf8(
                '{"jsonrpc":"2.0","id":1,"result":{ "txid":"dc1f7ab5db70c37c8dda87249d16e933eec1583a7a03b1d9a98166bef2661faf","hash":"dc1f7ab5db70c37c8dda87249d16e933eec1583a7a03b1d9a98166bef2661faf","block":"1666223"}}'
            )->{result});
    }
    'Subscription for Omni no memory growth for invalid transaction';
    no_growth {
        $omni_client->source;
    }
    'No memory growth';
};

done_testing;

