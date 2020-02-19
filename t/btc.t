#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::MockModule;
use Future::AsyncAwait;
use Net::Async::Blockchain::Transaction;
use Net::Async::Blockchain::BTC;

my $mock_rpc = Test::MockModule->new("Net::Async::Blockchain::Client::RPC::BTC");
my $mock_btc = Test::MockModule->new("Net::Async::Blockchain::BTC");

my $blockchain_btc = Net::Async::Blockchain::BTC->new();

subtest "hashblock & transform_transaction" => sub {

    $mock_rpc->mock(
        get_block => async sub {
            return {
                'confirmations'     => 2,
                'difficulty'        => 1,
                'time'              => 1582104444,
                'hash'              => '00000000a4bceeac7fd4a65e71447724e5e67e9d8d0d5a7e6906776eaa35e834',
                'previousblockhash' => '000000000005a678d87340aa0e21704eb5d0673d442a7ab0725bd169dff76897',
                'nonce'             => 2125810177,
                'version'           => 536870912,
                'merkleroot'        => 'b3b0bc9d339815842493796724dfc984eefbf6c122dba421c506f485c5ee20f7',
                'nTx'               => 1,
                'bits'              => '1d00ffff',
                'weight'            => 896,
                'strippedsize'      => 215,
                'tx'                => [{
                        'weight' => 572,
                        'hash'   => 'a2494b617bbae185645f9678a5bffd77b011f35aa66aff0c9fa7bfb6763fd378',
                        'size'   => 170,
                        'hex' =>
                            '010000000001010000000000000000000000000000000000000000000000000000000000000000ffffffff0403b06c19ffffffff02e40b54020000000017a914c61461766896a2becc3a2bbd82369c46b7ef4b24870000000000000000266a24aa21a9ede2f61c3f71d1defd3fa999dfa36953755c690689799962b48bebd836974e8cf90120000000000000000000000000000000000000000000000000000000000000000000000000',
                        'version'  => 1,
                        'vsize'    => 143,
                        'locktime' => 0,
                        'vout'     => [{
                                'scriptPubKey' => {
                                    'addresses' => ['2NBJaCLrahfVxFSysayeK91E3fxWLrTzUCU'],
                                    'hex'       => 'a914c61461766896a2becc3a2bbd82369c46b7ef4b2487',
                                    'asm'       => 'OP_HASH160 c61461766896a2becc3a2bbd82369c46b7ef4b24 OP_EQUAL',
                                    'reqSigs'   => 1,
                                    'type'      => 'scripthash'
                                },
                                'n'     => 0,
                                'value' => '0.390625'
                            },
                            {
                                'scriptPubKey' => {
                                    'type' => 'nulldata',
                                    'asm'  => 'OP_RETURN aa21a9ede2f61c3f71d1defd3fa999dfa36953755c690689799962b48bebd836974e8cf9',
                                    'hex'  => '6a24aa21a9ede2f61c3f71d1defd3fa999dfa36953755c690689799962b48bebd836974e8cf9'
                                },
                                'n'     => 1,
                                'value' => '0'
                            }
                        ],
                        'txid' => 'b3b0bc9d339815842493796724dfc984eefbf6c122dba421c506f485c5ee20f7',
                        'vin'  => [{
                                'sequence' => 4294967295,
                                'coinbase' => '03b06c19'
                            }]}
                ],
                'nextblockhash' => '0000000023563d72e89c7e185d90e153739667b413ee0b99c83002b941da8663',
                'versionHex'    => '20000000',
                'size'          => 251,
                'height'        => 1666224,
                'mediantime'    => 1582098354,
                'chainwork'     => '00000000000000000000000000000000000000000000014280a400c353418ad4'
            };
        },
        get_transaction => async sub {
            return 
            });

    my $expected_transaction = Net::Async::Blockchain::Transaction->new(
        currency     => 'BTC',
        hash         => '0x210850cef2c952387def5c40e23d7c8415e0abf2dd6ea0f5a9079f86b361dbae',
        block        => '8219294',
        from         => '0xe6c5de11dec1acda652bd7bf1e96fb56662e9f8f',
        to           => '0x1d8b942384c41be24f202d458e819640e6f0218a',
        contract     => '',
        amount       => Math::BigFloat->new(0.3292619388),
        fee          => Math::BigFloat->new(0.0004032),
        fee_currency => 'ETH',
        type         => '',
        data         => '0x',
    );

    $blockchain_btc->hashblock('00000000a4bceeac7fd4a65e71447724e5e67e9d8d0d5a7e6906776eaa35e834')->get;
};

done_testing;
