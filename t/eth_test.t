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
use Net::Async::Blockchain::Transaction;
use Net::Async::Blockchain::ETH;
use Net::Async::Redis;

no indirect;
use Ryu::Async;

my $mock_rpc = Test::MockModule->new("Net::Async::Blockchain::Client::RPC::ETH");
my $mock_eth = Test::MockModule->new("Net::Async::Blockchain::ETH");

my $loop = IO::Async::Loop->new();
$loop->add(my $blockchain_eth = Net::Async::Blockchain::ETH->new());

my $transaction_hash = '0x418aeca12f07c7010109b03d5d012f3c93f922ab520e831efb29075ae4903489';
my $address          = '0x8295507db4b0d6a18f6c69be7d5484d5dac3ed9d';

my $get_block_by_number = {
    'transactionsRoot' => '0xdf3c11f1b2cbb05ca53eeb3445aa848b05c4f0ccce00e55e735bdeb276a77341',
    'number'           => '0x6d56f',
    'hash'             => '0x1285db1573a082bbad24475599762f9460eccc49868884a944527605efede14d',
    'gasLimit'         => '0x7a1200',
    'timestamp'        => '0x5f571645',
    'parentHash'       => '0xd5412f2f096361237284aee60e341e0bc4ea554ee5eb671fa2bbd7c960e750ae',
    'difficulty'       => '0x2',
    'extraData' =>
        '0xd683010914846765746886676f312e3135856c696e7578000000000000000000b9ad6661c1423735db76761ca1272e99bb91c1814243dd1c89effc46320193196254a0b1ec84b106a8e1bdeea4046296ba30b6124c82a586f414cc7f4c9424b501',
    'stateRoot'    => '0x4b098f723cb2960f66cdce57412eaecee2ac390d17dcaf2f43ed2d3318e67d54',
    'transactions' => [{
            'hash'             => '0x418aeca12f07c7010109b03d5d012f3c93f922ab520e831efb29075ae4903489',
            'to'               => '0x8295507db4b0d6a18f6c69be7d5484d5dac3ed9d',
            'nonce'            => '0x56',
            'gas'              => '0x5208',
            'v'                => '0xa95',
            'blockNumber'      => '0x6d56f',
            'value'            => '0xa688906bd8b00000',
            'transactionIndex' => '0x0',
            'gasPrice'         => '0x1',
            'r'                => '0x4f272382dafff68bd7167bf4726397bef5df1d039ebdc16286833f40bb0d4b86',
            'input'            => '0x',
            'blockHash'        => '0x1285db1573a082bbad24475599762f9460eccc49868884a944527605efede14d',
            's'                => '0x403dc625a9bf3f062bc6d721bb02c8e57bb353917e719e54a49929deb438d56f',
            'from'             => '0x1f618fd55aaba65f1551c10b6022b7f9f0a2224c'
        }
    ],
    'logsBloom' =>
        '0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000',
    'uncles'          => [],
    'nonce'           => '0x0000000000000000',
    'gasUsed'         => '0x5208',
    'receiptsRoot'    => '0x056b23fbba480696b65fe5a59b8f2148a1299103c4f57df839233af2cf4ca2d2',
    'miner'           => '0x0000000000000000000000000000000000000000',
    'sha3Uncles'      => '0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347',
    'mixHash'         => '0x0000000000000000000000000000000000000000000000000000000000000000',
    'size'            => '0x2cf',
    'totalDifficulty' => '0xdaadf'
};

subtest "Test Case - to check transacform_transaction WITH Receipt" => sub {

    my $get_transaction_receipt = {
        'transactionIndex' => '0x0',
        'status'           => '0x1',
        'to'               => '0x8295507db4b0d6a18f6c69be7d5484d5dac3ed9d',
        'blockHash'        => '0x1285db1573a082bbad24475599762f9460eccc49868884a944527605efede14d',
        'logs'             => [],
        'from'             => '0x1f618fd55aaba65f1551c10b6022b7f9f0a2224c',
        'logsBloom' =>
            '0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000',
        'contractAddress'   => undef,
        'blockNumber'       => '0x6d56f',
        'cumulativeGasUsed' => '0x5208',
        'transactionHash'   => '0x418aeca12f07c7010109b03d5d012f3c93f922ab520e831efb29075ae4903489',
        'gasUsed'           => '0x5208'
    };

    my $expected_transaction = Net::Async::Blockchain::Transaction->new(
        currency     => 'ETH',
        hash         => $transaction_hash,
        block        => Math::BigInt->new(447855),
        from         => '0x1f618fd55aaba65f1551c10b6022b7f9f0a2224c',
        to           => $address,
        amount       => Math::BigFloat->new(12),
        fee          => Math::BigFloat->new(21000),
        fee_currency => 'ETH',
        type         => 'internal',
        timestamp    => 1599542853,
        contract     => '',
        data         => '0x',
    );

    # $loop->add(my $blockchain_eth = Net::Async::Blockchain::ETH->new());

    $mock_rpc->mock(
        get_block_by_number => async sub {
            return $get_block_by_number;
        },
        get_transaction_receipt => async sub {
            return $get_transaction_receipt;
        });

    $mock_eth->mock(
        accounts => sub {
            my %accounts = (
                lc "0x8295507db4b0d6a18f6c69be7d5484d5dac3ed9d" => 1,
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
            is_deeply $emitted_transaction, $expected_transaction, "Correct emitted trasnaction";
            $blockchain_eth_source->finish();
        });

    $blockchain_eth->newHeads({params => {result => {number => '0x6d56f'}}})->get;
    $blockchain_eth_source->get;

    $mock_rpc->unmock_all();
    $mock_eth->unmock_all();
};

subtest "Test Case - to check transacform_transaction WITHOUT Receipt" => sub {

    my $decoded_transaction = {
        'hash'             => '0x418aeca12f07c7010109b03d5d012f3c93f922ab520e831efb29075ae4903489',
        'to'               => '0x8295507db4b0d6a18f6c69be7d5484d5dac3ed9d',
        'nonce'            => '0x56',
        'gas'              => '0x5208',
        'v'                => '0xa95',
        'blockNumber'      => '0x6d56f',
        'value'            => '0xa688906bd8b00000',
        'transactionIndex' => '0x0',
        'gasPrice'         => '0x1',
        'r'                => '0x4f272382dafff68bd7167bf4726397bef5df1d039ebdc16286833f40bb0d4b86',
        'input'            => '0x',
        'blockHash'        => '0x1285db1573a082bbad24475599762f9460eccc49868884a944527605efede14d',
        's'                => '0x403dc625a9bf3f062bc6d721bb02c8e57bb353917e719e54a49929deb438d56f',
        'from'             => '0x1f618fd55aaba65f1551c10b6022b7f9f0a2224c'
    };

    $mock_rpc->mock(
        get_transaction_receipt => async sub {
            return undef;
        });

    my $response = $blockchain_eth->transform_transaction($decoded_transaction, '0x5f571645')->get;
    is $response, 0, "Correct response for transaction without receipt";

    $mock_rpc->unmock_all();
};

done_testing;
