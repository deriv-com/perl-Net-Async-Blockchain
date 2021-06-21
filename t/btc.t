#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::MockModule;
use Test::Exception;
use Test::TCP;
use Future::AsyncAwait;
use IO::Async::Loop;
use Math::BigFloat;
use ZMQ::LibZMQ3;
use ZMQ::Constants qw(:all);

use Net::Async::Blockchain::Transaction;
use Net::Async::Blockchain::BTC;
use Net::Async::Blockchain::Block;

my $mock_rpc = Test::MockModule->new("Net::Async::Blockchain::Client::RPC::BTC");
my $mock_btc = Test::MockModule->new("Net::Async::Blockchain::BTC");

my $loop = IO::Async::Loop->new();

my $transaction_hash = 'e7cc12f01de0860e867043ea877744f989e6f6d769c4cb5004c5a2475cc7c393';
my $address          = '2NCJunLYyxigRUQqVYMSdAfKh5zMmvZ9CYW';

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
            'hex'    =>
                '010000000001010000000000000000000000000000000000000000000000000000000000000000ffffffff0403b06c19ffffffff02e40b54020000000017a914c61461766896a2becc3a2bbd82369c46b7ef4b24870000000000000000266a24aa21a9ede2f61c3f71d1defd3fa999dfa36953755c690689799962b48bebd836974e8cf90120000000000000000000000000000000000000000000000000000000000000000000000000',
            'version'  => 1,
            'vsize'    => 143,
            'locktime' => 0,
            'vout'     => [{
                    'scriptPubKey' => {
                        'addresses' => [$address],
                        'hex'       => 'a914c61461766896a2becc3a2bbd82369c46b7ef4b2487',
                        'asm'       => 'OP_HASH160 c61461766896a2becc3a2bbd82369c46b7ef4b24 OP_EQUAL',
                        'reqSigs'   => 1,
                        'type'      => 'scripthash'
                    },
                    'n'     => 0,
                    'value' => '0.01050212'
                }
            ],
            'txid' => $transaction_hash,
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
            'address'  => $address,
            'amount'   => '0.01050212',
            'label'    => 'CR90000002',
            'vout'     => 0
        }
    ],
    'time'         => 1582001792,
    'blockhash'    => '000000000038c85a491a62fff3257f02a57c571d10fbe6740d0fe4a6921461fc',
    'txid'         => $transaction_hash,
    'timereceived' => 1582001792,
    'hex'          =>
        '02000000000101e20ef9d1d70903c8b2512461c2ece0db3c35378321988361d2e815e8f058420a0000000017160014aa14a6d3604846f2b6aeb887050fb1f7554dd947f ffffff02640610000000000017a914d11cdb2d8a8e43ca376dc81147896d6fd548706f8723b31a2c0000000017a914d1a74745adc1aed7d82ac430f2792124ad74665387024730440220300c9093b73157dc27d050c00c44dfa77be3279fff7f8de063b56f573fee41db02201723c112c07a8cfa37d23ae8fde8934540885213aff3f687db57530eb16dbb2b0121022bba14e339da55000e1d616a4d3ac6561543deca956621b0d89a7e015ace845e586c1900'
};

my $expected_transaction = Net::Async::Blockchain::Transaction->new(
    currency     => 'BTC',
    hash         => $transaction_hash,
    block        => Math::BigInt->new(1666224),
    from         => '',
    to           => $address,
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
                        'addresses' => [$address],
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
                        'addresses' => [$address],
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
                    'address'  => $address,
                    'amount'   => '0.01050212',
                    'label'    => 'CR90000002',
                    'vout'     => 0
                },
                {
                    'category' => 'receive',
                    'address'  => $address,
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
                        'addresses' => [$address],
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
                        'addresses' => [$address],
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
                    'address'  => $address,
                    'amount'   => '0.01',
                    'label'    => 'dummy',
                    'vout'     => 0
                },
                {
                    'category' => 'send',
                    'address'  => $address,
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

subtest "Transaction with category send" => sub {

    $loop->add(my $blockchain_btc = Net::Async::Blockchain::BTC->new());

    $mock_rpc->mock(
        get_block => async sub {

            my $get_block_value_cp = $get_block_value;
            my $new_vout           = [{
                    'scriptPubKey' => {
                        'addresses' => [$address],
                        'hex'       => 'a914c61461766896a2becc3a2bbd82369c46b7ef4b2487',
                        'asm'       => 'OP_HASH160 c61461766896a2becc3a2bbd82369c46b7ef4b24 OP_EQUAL',
                        'reqSigs'   => 1,
                        'type'      => 'scripthash'
                    },
                    'n'     => 0,
                    'value' => '-0.01'
                }];

            $get_block_value_cp->{tx}->[0]->{vout} = $new_vout;
            return $get_block_value_cp;
        },
        get_transaction => async sub {

            my $get_transaction_value_cp = $get_transaction_value;
            my $new_details              = [{
                    'category' => 'send',
                    'address'  => $address,
                    'amount'   => '-0.01',
                    'label'    => 'dummy',
                    'vout'     => 0,
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
            $expected_transaction_cp->{amount} = Math::BigFloat->new('-0.01');
            $expected_transaction_cp->{type}   = 'send';
            $expected_transaction_cp->{fee}    = Math::BigFloat->new('-2.56e-06');
            is_deeply $emitted_transaction, $expected_transaction_cp, "Correct emitted trasnaction";
            $blockchain_btc_source->finish();
        });

    $blockchain_btc->hashblock('00000000a4bceeac7fd4a65e71447724e5e67e9d8d0d5a7e6906776eaa35e834')->get;
    $blockchain_btc_source->get;

    $mock_rpc->unmock_all();
};

subtest "recursive_search _ base block number is undefined" => sub {

    $loop->add(my $blockchain_btc = Net::Async::Blockchain::BTC->new());
    my $value = $blockchain_btc->recursive_search->get;
    is $value, undef, "Correct response";
    is $blockchain_btc->{base_block_number}, undef, "base block number is not passed";
};

subtest "recursive_search _ break the while loop" => sub {

    $loop->add(my $blockchain_btc = Net::Async::Blockchain::BTC->new(base_block_number => 500));
    $mock_rpc->mock(
        get_last_block => async sub {
            return 499;
        });
    my $value = $blockchain_btc->recursive_search->get;
    is $blockchain_btc->{base_block_number}, 500, "base block number has not increased";
    $mock_rpc->unmock_all();
};

subtest "recursive_search" => sub {

    my $block_number = 500;
    $loop->add(
        my $blockchain_btc = Net::Async::Blockchain::BTC->new(
            currency_symbol   => 'BTC',
            base_block_number => $block_number
        ));
    $mock_rpc->mock(
        get_last_block => async sub {
            return $block_number;
        },
        get_block_hash => async sub {
            return '00000000a4bceeac7fd4a65e71447724e5e67e9d8d0d5a7e6906776eaa35e834';
        });

    $mock_btc->mock(
        hashblock => async sub {
            return $block_number;
        });

    my $expected_data = Net::Async::Blockchain::Block->new(
        number   => $block_number,
        currency => $blockchain_btc->currency_symbol
    );

    my $source = $blockchain_btc->source->each(
        sub {
            my $emitted_data = shift;
            is_deeply $emitted_data, $expected_data, "Correct emitted data";
            $blockchain_btc->source->finish();
        });

    $blockchain_btc->recursive_search->get;

    $source->get;

    $mock_rpc->unmock_all();
    $mock_btc->unmock_all();
};

subtest "subscribe _ wrong subscription type" => sub {

    $loop->add(my $blockchain_btc = Net::Async::Blockchain::BTC->new());
    dies_ok { $blockchain_btc->subscribe('dummy') } 'expecting to die due to wrong subscription type';
};

subtest "subscribe" => sub {

    # ZMQ server
    my $block_hash_bytes = pack('H*', '00000000a4bceeac7fd4a65e71447724e5e67e9d8d0d5a7e6906776eaa35e834');
    my @msg              = ('hashblock', $block_hash_bytes);
    my $zmq_server       = Test::TCP->new(
        code => sub {
            my $port = shift;
            my $ctxt = zmq_init();
            my $sock = zmq_socket($ctxt, ZMQ_PUB);

            zmq_bind($sock, "tcp://127.0.0.1:$port");
            sleep 2;
            for (@msg) {
                zmq_sendmsg($sock, zmq_msg_init_data($_), ZMQ_SNDMORE);
            }
            zmq_sendmsg($sock, zmq_msg_init_data("last"), 0);
            exit 0;
        });

    my $port = $zmq_server->port;
    my $ctxt = zmq_init();
    my $sock = zmq_socket($ctxt, ZMQ_SUB);

    $loop->add(my $blockchain_btc = Net::Async::Blockchain::BTC->new(subscription_url => "tcp://127.0.0.1:$port"));

    $mock_btc->mock(
        recursive_search => async sub {
            return undef;
        });

    $mock_rpc->mock(
        get_block => async sub {
            return $get_block_value;
        },
        get_transaction => async sub {
            return $get_transaction_value;
        });

    my $btc_subscribe = $blockchain_btc->subscribe('transactions');
    is ref $btc_subscribe, 'Ryu::Source', 'correct reference for Ryu Source';

    $btc_subscribe->each(
        sub {
            my $emitted_transaction = shift;
            is_deeply $emitted_transaction, $expected_transaction, "Correct emitted trasnaction";
            $btc_subscribe->finish();
        })->get;

    zmq_close($blockchain_btc->zmq_client->socket_client());
    $mock_rpc->unmock_all();
    $mock_btc->unmock_all();
};

done_testing;
