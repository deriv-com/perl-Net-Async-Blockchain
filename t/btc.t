#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::MockModule;
use Future::AsyncAwait;
use Math::BigFloat;
use IO::Async::Loop;

use Net::Async::Blockchain::Transaction;
use Net::Async::Blockchain::BTC;

my $mock_rpc = Test::MockModule->new("Net::Async::Blockchain::Client::RPC::BTC");

my $loop = IO::Async::Loop->new();

my $get_block_value = {
    'confirmations'     => 2,
    'difficulty'        => 1,
    'time'              => 1582104444,
    'hash'              => '000000000038c85a491a62fff3257f02a57c571d10fbe6740d0fe4a6921461fc',
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
                        'addresses' => ['2NCJunLYyxigRUQqVYMSdAfKh5zMmvZ9CYW'],
                        'hex'       => 'a914c61461766896a2becc3a2bbd82369c46b7ef4b2487',
                        'asm'       => 'OP_HASH160 c61461766896a2becc3a2bbd82369c46b7ef4b24 OP_EQUAL',
                        'reqSigs'   => 1,
                        'type'      => 'scripthash'
                    },
                    'n'     => 0,
                    'value' => '0.01050212'
                }
            ],
            'txid' => 'e7cc12f01de0860e867043ea877744f989e6f6d769c4cb5004c5a2475cc7c393',
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
my $get_transaction_value = {
    'amount'             => '0.01050212',
    'blocktime'          => 1582002572,
    'walletconflicts'    => [],
    'bip125-replaceable' => 'no',
    'blockindex'         => 37,
    'confirmations'      => 138,
    'details'            => [{
            'category' => 'receive',
            'address'  => '2NCJunLYyxigRUQqVYMSdAfKh5zMmvZ9CYW',
            'amount'   => '0.01050212',
            'label'    => 'CR90000002',
            'vout'     => 0
        }
    ],
    'time'         => 1582001792,
    'blockhash'    => '000000000038c85a491a62fff3257f02a57c571d10fbe6740d0fe4a6921461fc',
    'txid'         => 'e7cc12f01de0860e867043ea877744f989e6f6d769c4cb5004c5a2475cc7c393',
    'timereceived' => 1582001792,
    'hex' =>
        '02000000000101e20ef9d1d70903c8b2512461c2ece0db3c35378321988361d2e815e8f058420a0000000017160014aa14a6d3604846f2b6aeb887050fb1f7554dd947f ffffff02640610000000000017a914d11cdb2d8a8e43ca376dc81147896d6fd548706f8723b31a2c0000000017a914d1a74745adc1aed7d82ac430f2792124ad74665387024730440220300c9093b73157dc27d050c00c44dfa77be3279fff7f8de063b56f573fee41db02201723c112c07a8cfa37d23ae8fde8934540885213aff3f687db57530eb16dbb2b0121022bba14e339da55000e1d616a4d3ac6561543deca956621b0d89a7e015ace845e586c1900'
};

my $expected_transaction = Net::Async::Blockchain::Transaction->new(
    currency     => 'BTC',
    hash         => 'e7cc12f01de0860e867043ea877744f989e6f6d769c4cb5004c5a2475cc7c393',
    block        => Math::BigInt->new(1666224),
    from         => '',
    to           => '2NCJunLYyxigRUQqVYMSdAfKh5zMmvZ9CYW',
    amount       => Math::BigFloat->new(0.01050212),
    fee          => Math::BigFloat->new(0),
    fee_currency => 'BTC',
    type         => 'receive',
    timestamp    => 1582002572,
);

subtest "Transaction with category receive _ one output" => sub {

    $loop->add(my $blockchain_btc = Net::Async::Blockchain::BTC->new());

    $mock_rpc->mock(
        get_block => async sub {
            return $get_block_value;
        },
        get_transaction => async sub {
            return $get_transaction_value;
        });

    my $blockchain_btc_source = $blockchain_btc->source;
    $blockchain_btc_source->each(
        sub {
            my $emitted_transaction = shift;
            is_deeply $emitted_transaction, $expected_transaction, "Correct emitted trasnaction";
            $blockchain_btc_source->finish();
        });

    $blockchain_btc->hashblock('00000000a4bceeac7fd4a65e71447724e5e67e9d8d0d5a7e6906776eaa35e834')->get;
    $blockchain_btc_source->get;

    $mock_rpc->unmock_all();
};

subtest "Transaction with category receive _ two outputs" => sub {

    $loop->add(my $blockchain_btc = Net::Async::Blockchain::BTC->new());

    $mock_rpc->mock(
        get_block => async sub {

            my $get_block_value_cp = $get_block_value;
            my $new_vout           = [{
                    'scriptPubKey' => {
                        'addresses' => ['2NCJunLYyxigRUQqVYMSdAfKh5zMmvZ9CYW'],
                        'hex'       => 'a914c61461766896a2becc3a2bbd82369c46b7ef4b2487',
                        'asm'       => 'OP_HASH160 c61461766896a2becc3a2bbd82369c46b7ef4b24 OP_EQUAL',
                        'reqSigs'   => 1,
                        'type'      => 'scripthash'
                    },
                    'n'     => 0,
                    'value' => '0.01050212'
                },
                {
                    'scriptPubKey' => {
                        'addresses' => ['2NCJunLYyxigRUQqVYMSdAfKh5zMmvZ9CYW'],
                        'hex'       => 'a914c61461766896a2becc3a2bbd82369c46b7ef4b2487',
                        'asm'       => 'OP_HASH160 c61461766896a2becc3a2bbd82369c46b7ef4b24 OP_EQUAL',
                        'reqSigs'   => 1,
                        'type'      => 'scripthash'
                    },
                    'n'     => 1,
                    'value' => '0.01'
                }];

            $get_block_value_cp->{tx}->[0]->{vout} = $new_vout;
            return $get_block_value_cp;
        },
        get_transaction => async sub {

            my $get_transaction_value_cp = $get_transaction_value;
            my $new_details              = [{
                    'category' => 'receive',
                    'address'  => '2NCJunLYyxigRUQqVYMSdAfKh5zMmvZ9CYW',
                    'amount'   => '0.01050212',
                    'label'    => 'CR90000002',
                    'vout'     => 0
                },
                {
                    'category' => 'receive',
                    'address'  => '2NCJunLYyxigRUQqVYMSdAfKh5zMmvZ9CYW',
                    'amount'   => '0.01',
                    'label'    => 'CR90000002',
                    'vout'     => 1
                }];
            $get_transaction_value_cp->{details} = $new_details;
            return $get_transaction_value_cp;
        });

    my $blockchain_btc_source = $blockchain_btc->source;
    $blockchain_btc_source->each(
        sub {
            my $emitted_transaction     = shift;
            my $expected_transaction_cp = $expected_transaction;
            $expected_transaction_cp->{amount} = Math::BigFloat->new(0.02050212);
            is_deeply $emitted_transaction, $expected_transaction_cp, "Correct emitted trasnaction";
            $blockchain_btc_source->finish();
        });

    $blockchain_btc->hashblock('00000000a4bceeac7fd4a65e71447724e5e67e9d8d0d5a7e6906776eaa35e834')->get;
    $blockchain_btc_source->get;

    $mock_rpc->unmock_all();
};

subtest "Transaction with category internal" => sub {

    $loop->add(my $blockchain_btc = Net::Async::Blockchain::BTC->new());

    $mock_rpc->mock(
        get_block => async sub {

            my $get_block_value_cp = $get_block_value;
            my $new_vout           = [{
                    'scriptPubKey' => {
                        'addresses' => ['2NCJunLYyxigRUQqVYMSdAfKh5zMmvZ9CYW'],
                        'hex'       => 'a914c61461766896a2becc3a2bbd82369c46b7ef4b2487',
                        'asm'       => 'OP_HASH160 c61461766896a2becc3a2bbd82369c46b7ef4b24 OP_EQUAL',
                        'reqSigs'   => 1,
                        'type'      => 'scripthash'
                    },
                    'n'     => 0,
                    'value' => '0.01'
                },
                {
                    'scriptPubKey' => {
                        'addresses' => ['2NCJunLYyxigRUQqVYMSdAfKh5zMmvZ9CYW'],
                        'hex'       => 'a914c61461766896a2becc3a2bbd82369c46b7ef4b2487',
                        'asm'       => 'OP_HASH160 c61461766896a2becc3a2bbd82369c46b7ef4b24 OP_EQUAL',
                        'reqSigs'   => 1,
                        'type'      => 'scripthash'
                    },
                    'n'     => 1,
                    'value' => '-0.01'
                }];

            $get_block_value_cp->{tx}->[0]->{vout} = $new_vout;
            return $get_block_value_cp;
        },
        get_transaction => async sub {

            my $get_transaction_value_cp = $get_transaction_value;
            my $new_details              = [{
                    'category' => 'receive',
                    'address'  => '2NCJunLYyxigRUQqVYMSdAfKh5zMmvZ9CYW',
                    'amount'   => '0.01',
                    'label'    => 'dummy',
                    'vout'     => 0
                },
                {
                    'category' => 'send',
                    'address'  => '2NCJunLYyxigRUQqVYMSdAfKh5zMmvZ9CYW',
                    'amount'   => '-0.01',
                    'label'    => 'dummy',
                    'vout'     => 1,
                    'fee'      => '-2.56e-06'
                }];
            $get_transaction_value_cp->{details} = $new_details;
            $get_transaction_value_cp->{fee}     = '-2.56e-06';
            return $get_transaction_value_cp;
        });

    my $blockchain_btc_source = $blockchain_btc->source;
    $blockchain_btc_source->each(
        sub {
            my $emitted_transaction     = shift;
            my $expected_transaction_cp = $expected_transaction;
            $expected_transaction_cp->{amount} = Math::BigFloat->new(0);
            $expected_transaction_cp->{type}   = 'internal';
            $expected_transaction_cp->{fee}    = Math::BigFloat->new('-2.56e-06');
            is_deeply $emitted_transaction, $expected_transaction_cp, "Correct emitted trasnaction";
            $blockchain_btc_source->finish();
        });

    $blockchain_btc->hashblock('00000000a4bceeac7fd4a65e71447724e5e67e9d8d0d5a7e6906776eaa35e834')->get;
    $blockchain_btc_source->get;

    $mock_rpc->unmock_all();
};

done_testing;
