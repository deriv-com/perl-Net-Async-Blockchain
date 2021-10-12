#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;
use Test::MockModule;
use Test::MemoryGrowth;
use Net::Async::Blockchain::ETH;
use Net::Async::WebSocket::Server;
use JSON::MaybeUTF8 qw(decode_json_utf8);
use Future::AsyncAwait;

plan skip_all => "Ignoring test: The test is failing intermittently on master" unless $ENV{TRAVIS};

my $loop = IO::Async::Loop->new;

my $module_rpc = Test::MockModule->new('Net::Async::Blockchain::Client::RPC::ETH');
my $module_eth = Test::MockModule->new('Net::Async::Blockchain::ETH');

my $accounts =
    [
    ("0x72338b82800400f5488eca2b5a37270ba3b7a111", "0x65798e5c90a332bbfa37c793f8847c441df42d44", "0x05cde89ccfa0ada8c88d5a23caaa79ef129e7883") x 5000
    ];

my %accounts = map { lc($_) => 1 } $accounts->@*;

$module_rpc->mock(
    'get_transaction_receipt' => async sub {
        my (undef, $tx) = @_;
        if ($tx eq "0x1a7d89fcbba627f9c82ac8edcf93180c84a5ae754418589787a703ad4a974870") {
            return decode_json_utf8(
                '{"jsonrpc":"2.0","id":1,"result":{"blockHash":"0xf3284e85de5c9eb5199530d0c47b6006b5c480135975f72c352b4d12d16c9643","blockNumber":"0x897712","contractAddress":null,"cumulativeGasUsed":"0x7f613a","from":"0x65798e5c90a332bbfa37c793f8847c441df42d44","gasUsed":"0x5fb9","logs":[],"logsBloom":"0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000","status":"0x0","to":"0x72338b82800400f5488eca2b5a37270ba3b7a111","transactionHash":"0x1a7d89fcbba627f9c82ac8edcf93180c84a5ae754418589787a703ad4a974870","transactionIndex":"0x79"}}'
            )->{result};
        } else {
            return decode_json_utf8(
                '{"jsonrpc":"2.0","id":1,"result":{"blockHash":"0x3c41c39281a8509620644e90f013b24208b705069a00dd99b6b7b5389ece1fd1","blockNumber":"0x8e7926","contractAddress":null,"cumulativeGasUsed":"0x1244d2","from":"0x44e6fc81de0f718a3f23d266aa28c27069eff045","gasUsed":"0x121c6","logs":[{"address":"0x2b591e99afe9f32eaa6214f7b7629768c40eeb39","topics":["0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef","0x00000000000000000000000044e6fc81de0f718a3f23d266aa28c27069eff045","0x00000000000000000000000005cde89ccfa0ada8c88d5a23caaa79ef129e7883"],"data":"0x00000000000000000000000000000000000000000000000000005aeb9045e6bc","blockNumber":"0x8e7926","transactionHash":"0x67e16a265f3ae0ce0a0be05822c62bf246024ab70039a2cdbb60c112a3bcae24","transactionIndex":"0x16","blockHash":"0x3c41c39281a8509620644e90f013b24208b705069a00dd99b6b7b5389ece1fd1","logIndex":"0xa","removed":false},{"address":"0x2b591e99afe9f32eaa6214f7b7629768c40eeb39","topics":["0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925","0x00000000000000000000000044e6fc81de0f718a3f23d266aa28c27069eff045","0x00000000000000000000000005cde89ccfa0ada8c88d5a23caaa79ef129e7883"],"data":"0xfffffffffffffffffffffffffffffffffffffffffffffffffffe0b9336316209","blockNumber":"0x8e7926","transactionHash":"0x67e16a265f3ae0ce0a0be05822c62bf246024ab70039a2cdbb60c112a3bcae24","transactionIndex":"0x16","blockHash":"0x3c41c39281a8509620644e90f013b24208b705069a00dd99b6b7b5389ece1fd1","logIndex":"0xb","removed":false},{"address":"0x05cde89ccfa0ada8c88d5a23caaa79ef129e7883","topics":["0x06239653922ac7bea6aa2b19dc486b9361821d37712eb796adfd38d81de278ca","0x00000000000000000000000044e6fc81de0f718a3f23d266aa28c27069eff045","0x00000000000000000000000000000000000000000000000009616c79b534d08d","0x00000000000000000000000000000000000000000000000000005aeb9045e6bc"],"data":"0x","blockNumber":"0x8e7926","transactionHash":"0x67e16a265f3ae0ce0a0be05822c62bf246024ab70039a2cdbb60c112a3bcae24","transactionIndex":"0x16","blockHash":"0x3c41c39281a8509620644e90f013b24208b705069a00dd99b6b7b5389ece1fd1","logIndex":"0xc","removed":false},{"address":"0x05cde89ccfa0ada8c88d5a23caaa79ef129e7883","topics":["0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef","0x0000000000000000000000000000000000000000000000000000000000000000","0x00000000000000000000000044e6fc81de0f718a3f23d266aa28c27069eff045"],"data":"0x0000000000000000000000000000000000000000000000000cea06aa72f3fef8","blockNumber":"0x8e7926","transactionHash":"0x67e16a265f3ae0ce0a0be05822c62bf246024ab70039a2cdbb60c112a3bcae24","transactionIndex":"0x16","blockHash":"0x3c41c39281a8509620644e90f013b24208b705069a00dd99b6b7b5389ece1fd1","logIndex":"0xd","removed":false}],"logsBloom":"0x00000000000000000000408000000000000000000400000000000000000000000000200000000000000000000000000000000000000000000000000000200000000000000004000001400008000000000000000000000000000000080000000000000000020000000000000000000800000000000000000000000010000008000000000000000000000000000000000000000000010000000000400000000000024000000000000000440000000000040000000020020000000000000000080000080002000000000000000000000000000000000000000000000000400020000010000000000000000000000000000000000000000000000000000000000200","status":"0x1","to":"0x05cde89ccfa0ada8c88d5a23caaa79ef129e7883","transactionHash":"0x67e16a265f3ae0ce0a0be05822c62bf246024ab70039a2cdbb60c112a3bcae24","transactionIndex":"0x16"}}'
            );
        }
    },
    'accounts' => async sub {
        return $accounts;
    },
    'call' => async sub {
        my $data = shift;
        if ($data eq Net::Async::Blockchain::ETH::SYMBOL_SIGNATURE) {
            return '0x0000000000000000000000000000000000000000000000000000000045544844';
        } elsif ($data eq Net::Async::Blockchain::ETH::DECIMALS_SIGNATURE) {
            return '0x0000000000000000000000000000000000000000000000000000000000000012';
        }
    });

$module_eth->mock('UPDATE_ACCOUNTS' => 0.1);

$loop->add(
    my $eth_client = Net::Async::Blockchain::ETH->new(
        subscription_url => "ws://127.0.0.1:8546",
        rpc_url          => "http://127.0.0.1:8545",
    ));

is $eth_client->UPDATE_ACCOUNTS, 0.1, "correct mock for account update time";

subtest "Ethereum memory test" => sub {
    no_growth {
        $eth_client->transform_transaction(
            decode_json_utf8(
                '{"jsonrpc":"2.0","id":1,"result":{"blockHash":"0xf3284e85de5c9eb5199530d0c47b6006b5c480135975f72c352b4d12d16c9643","blockNumber":"0x897712","from":"0x65798e5c90a332bbfa37c793f8847c441df42d44","gas":"0x186a0","gasPrice":"0x17d784000","hash":"0x1a7d89fcbba627f9c82ac8edcf93180c84a5ae754418589787a703ad4a974870","input":"0xa9059cbb0000000000000000000000002f3593fb5a2b151f1586c77dd687b045fe4e79cc08c379a000000000000000000000000000000000000000000000000000000000","nonce":"0xac","to":"0x72338b82800400f5488eca2b5a37270ba3b7a111","transactionIndex":"0x79","value":"0x0","v":"0x26","r":"0x55461307a793df6a357da442074a5bc463c0e687d069d391a60d9c56f4fcf6a7","s":"0x505ade41db5a0962eb90fc1233bba93f85fe1d74a955aa9621759a6e9762991b"}}'
            )->{result},
            time
        );
    }
    'Subscription for ETH/ERC20 no memory growth for invalid transaction';
    no_growth {
        $eth_client->transform_transaction(
            decode_json_utf8(
                '{"jsonrpc":"2.0","id":1,"result":{"blockHash":"0x3c41c39281a8509620644e90f013b24208b705069a00dd99b6b7b5389ece1fd1","blockNumber":"0x8e7926","from":"0x44e6fc81de0f718a3f23d266aa28c27069eff045","gas":"0x14229","gasPrice":"0x3b9aca00","hash":"0x67e16a265f3ae0ce0a0be05822c62bf246024ab70039a2cdbb60c112a3bcae24","input":"0x422f10430000000000000000000000000000000000000000000000000ca7e7d00003989700000000000000000000000000000000000000000000000000005cbd132894a6000000000000000000000000000000000000000000000000000000005e296b32","nonce":"0x67","to":"0x05cde89ccfa0ada8c88d5a23caaa79ef129e7883","transactionIndex":"0x16","value":"0x9616c79b534d08d","v":"0x26","r":"0x1f7a7187bd474cde0ad208a0c92f8b32c5305f882623ecde980d9473dc3125d","s":"0x601a80d2c17048b0ea6c2118fb400787fc67ee22f3f33649e9350badf87876a6"}}'
            )->{result},
            time
        );
    }
    'Subscription for ETH/ERC20 no memory growth for a valid contract transaction';
    no_growth {
        $eth_client->get_hash_accounts()->get;
    }
    'No memory growth while loading accounts';
};

done_testing;
