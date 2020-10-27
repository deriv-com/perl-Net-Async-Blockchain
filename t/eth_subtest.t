#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::MockModule;
use Test::Exception;
use Test::TCP;

use Future::AsyncAwait;
use IO::Async::Loop;

use Math::BigInt;
use Math::BigFloat;
use JSON::MaybeUTF8 qw(decode_json_utf8 encode_json_utf8);
use Net::Async::Blockchain::Transaction;
use Net::Async::Blockchain::ETH;
use Net::Async::Redis;

no indirect;
use Ryu::Async;

my $mock_rpc = Test::MockModule->new("Net::Async::Blockchain::Client::RPC::ETH");
my $mock_eth = Test::MockModule->new("Net::Async::Blockchain::ETH");

my $loop = IO::Async::Loop->new();
$loop->add(my $blockchain_eth = Net::Async::Blockchain::ETH->new());

subtest "Test Case - to check _transform_unprocessed_transactions" => (
    sub {
        $loop->add(
            my $redis_client = Net::Async::Redis->new(
                uri => 'redis://localhost:6379',
                auth => undef,
            ));

        my $redis_key = "eth::subscription::unprocessed_transaction";

        my $sample_get_transaction_receipt = {
            'transactionIndex' => '0x0',
            'status'           => '0x1',
            'to'               => '0x8295507db4b0d6a18f6c69be7d5484d5dac3ed9c',
            'blockHash'        => '0x1285db1573a082bbad24475599762f9460eccc49868884a944527605efede14d',
            'logs'             => [],
            'from'             => '0x1f618fd55aaba65f1551c10b6022b7f9f0a2224c',
            'logsBloom' =>
                '0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000',
            'contractAddress'   => undef,
            'blockNumber'       => '0x74ea8',
            'cumulativeGasUsed' => '0x5208',
            'transactionHash'   => '0x418aeca12f07c7010109b03d5d012f3c93f922ab520e831efb29075ae4903488',
            'gasUsed'           => '0x5208'
        };

        my $expected_transaction = Net::Async::Blockchain::Transaction->new(
            currency     => 'ETH',
            hash         => '0x418aeca12f07c7010109b03d5d012f3c93f922ab520e831efb29075ae4903488',
            block        => Math::BigInt->new(478888),
            from         => '0x1f618fd55aaba65f1551c10b6022b7f9f0a2224c',
            to           => '0x8295507db4b0d6a18f6c69be7d5484d5dac3ed9c',
            amount       => Math::BigFloat->new(12),
            fee          => Math::BigFloat->new(21000),
            fee_currency => 'ETH',
            type         => 'internal',
            timestamp    => 1599542853,
            contract     => '',
            data         => '0x',
        );

        my $decoded_transaction = {
            'hash'             => '0x418aeca12f07c7010109b03d5d012f3c93f922ab520e831efb29075ae4903488',
            'to'               => '0x8295507db4b0d6a18f6c69be7d5484d5dac3ed9c',
            'nonce'            => '0x56',
            'gas'              => '0x5208',
            'v'                => '0xa95',
            'blockNumber'      => '0x74ea8',
            'value'            => '0xa688906bd8b00000',
            'transactionIndex' => '0x0',
            'gasPrice'         => '0x1',
            'r'                => '0x4f272382dafff68bd7167bf4726397bef5df1d039ebdc16286833f40bb0d4b86',
            'input'            => '0x',
            'blockHash'        => '0x1285db1573a082bbad24475599762f9460eccc49868884a944527605efede14d',
            's'                => '0x403dc625a9bf3f062bc6d721bb02c8e57bb353917e719e54a49929deb438d56f',
            'from'             => '0x1f618fd55aaba65f1551c10b6022b7f9f0a2224c',
            'timestamp'        => '0x5f571645',
            'flag'             => 1
        };

        # Add the transaction in the redis queue
        if ($decoded_transaction->{flag} && $decoded_transaction->{flag} <= 5) {
            $redis_client->connect->get;
            $redis_client->rpush($redis_key => encode_json_utf8($decoded_transaction))->get;
        }

        $mock_rpc->mock(
            get_transaction_receipt => async sub {
                return $sample_get_transaction_receipt;
            });

        $mock_eth->mock(
            accounts => sub {
                my %accounts = (
                    lc '0x8295507db4b0d6a18f6c69be7d5484d5dac3ed9c' => 1,
                    lc "0x1f618fd55aaba65f1551c10b6022b7f9f0a2224c" => 1
                );
                return \%accounts;
            },
            _check_contract_transaction => async sub {
                return ();
            },
            _set_transaction_type => async sub {
                my ($self, $transaction) = @_;
                $transaction->{type} = 'internal';
                return $transaction;
            },
            latest_accounts_update => sub {
                return time;
            });

        my $blockchain_eth_source = $blockchain_eth->source;
        $blockchain_eth_source->each(
            sub {
                my $emitted_transaction = shift;
                is_deeply $emitted_transaction, $expected_transaction, "Correct emitted transaction";
                $blockchain_eth_source->finish();
            });

        $blockchain_eth->_transform_unprocessed_transactions()->get;

        $mock_rpc->unmock_all();
        $mock_eth->unmock_all();
        $redis_client->flushall;
    });

done_testing;
