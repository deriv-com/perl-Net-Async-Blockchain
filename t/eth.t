#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;
use Test::MockModule;
use Future::AsyncAwait;
use Net::Async::Blockchain::Transaction;
use Net::Async::Blockchain::ETH;
use Net::Async::Blockchain::Client::RPC::ETH;
use Net::Async::Blockchain::Plugins::ETH::Utility;
use JSON::MaybeUTF8 qw(encode_json_utf8 decode_json_utf8);

my $transaction = Net::Async::Blockchain::Transaction->new(
    currency     => 'ETH',
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

my $subscription_client = Net::Async::Blockchain::ETH->new();
my $plugin_utility      = Net::Async::Blockchain::Plugins::ETH::Utility->new();

my $mock_rpc = Test::MockModule->new("Net::Async::Blockchain::Client::RPC::ETH");
my $mock_eth = Test::MockModule->new("Net::Async::Blockchain::ETH");

$mock_eth->mock(
    accounts => async sub {
        my %accounts = (lc "0x1D8b942384c41Be24f202d458e819640E6f0218a" => 1);
        return \%accounts;
    });

my $received_transaction = $subscription_client->_set_transaction_type($transaction)->get;

is $received_transaction->{type}, 'receive', "valid transaction type for `to` address";

$mock_eth->mock(
    accounts => async sub {
        my %accounts = (lc "0xe6c5De11DEc1aCda652BD7bF1E96fb56662E9f8F" => 1);
        return \%accounts;
    });

$received_transaction = $subscription_client->_set_transaction_type($transaction)->get;

is $received_transaction->{type}, 'sent', "valid transaction type for `from` address";

$mock_eth->mock(
    accounts => async sub {
        my %accounts = (lc "0xe6c5De11DEc1aCda652BD7bF1E96fb56662E9f8F" => 1, lc "0x1D8b942384c41Be24f202d458e819640E6f0218a" => 1);
        return \%accounts;
    });

$received_transaction = $subscription_client->_set_transaction_type($transaction)->get;

is $received_transaction->{type}, 'internal', "valid transaction type for `from` and `to` address";

$mock_rpc->mock(
    get_transaction_receipt => async sub {
        return {logs => []};
    });

is $plugin_utility->_remove_zeros("0x0f72a63496D0D5F17d3186750b65226201963716"), "0x0f72a63496D0D5F17d3186750b65226201963716",
    "no zeros to be removed";
is $plugin_utility->_remove_zeros("0x000000000000000000000000000000000f72a63496D0D5F17d3186750b65226201963716"),
    "0x0f72a63496D0D5F17d3186750b65226201963716", "removes only not needed zeros";

$transaction = Net::Async::Blockchain::Transaction->new(
    currency     => 'ETH',
    hash         => '0x382dc93eae2df291bd5e885499778ac871babba3e2c5dcbf308be7c06be84739',
    block        => '8224186',
    from         => '0x0749c36df05f1ddb6cc0c797c94a676499191851',
    to           => '0xdac17f958d2ee523a2206206994597c13d831ec7',
    contract     => '',
    amount       => Math::BigFloat->bzero(),
    fee          => Math::BigFloat->new(0.00023465),
    fee_currency => 'ETH',
    type         => '',
    data =>
        '0xa9059cbb0000000000000000000000002ae6d1401af58f9fbe2eda032b8494d519af5813000000000000000000000000000000000000000000000000000000003b9aca00',
);

# curl -H "Content-Type: application/json" -X POST --data '{"jsonrpc":"2.0","method":"eth_getTransactionReceipt","params":["0x382dc93eae2df291bd5e885499778ac871babba3e2c5dcbf308be7c06be84739"],"id":1}' http://localhost:8545
my $receipt =
    decode_json_utf8('{"jsonrpc":"2.0","id":1,"result":{"blockHash":"0x2e16030779d881acd4306aa7d00ba9a9177b0b28d9ef334b607ff47d712e558c","blockNumber":"0x7d7da1","contractAddress":null,"cumulativeGasUsed":"0x4e68a5","from":"0x32d038a19f75b2ba4ca1d38a82192ff353c47be2","gasUsed":"0x9601","logs":[{"address":"0xdac17f958d2ee523a2206206994597c13d831ec7","topics":["0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef","0x00000000000000000000000032d038a19f75b2ba4ca1d38a82192ff353c47be2","0x0000000000000000000000002ae6d1401af58f9fbe2eda032b8494d519af5813"],"data":"0x000000000000000000000000000000000000000000000000000000003b9aca00","blockNumber":"0x7d7da1","transactionHash":"0x382dc93eae2df291bd5e885499778ac871babba3e2c5dcbf308be7c06be84739","transactionIndex":"0x91","blockHash":"0x2e16030779d881acd4306aa7d00ba9a9177b0b28d9ef334b607ff47d712e558c","logIndex":"0x49","removed":false}],"logsBloom":"0x00000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000010000000000000000000020000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000400000000000000000000000100000000000000000000000000080000000000000000000000000000002000000000000000002000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000004","status":"0x1","to":"0xdac17f958d2ee523a2206206994597c13d831ec7","transactionHash":"0x382dc93eae2df291bd5e885499778ac871babba3e2c5dcbf308be7c06be84739","transactionIndex":"0x91"}}');

$mock_rpc->mock(
    call => async sub {
        my ($self, $args) = @_;
        if ($args->{data} eq Net::Async::Blockchain::Plugins::ETH::ERC20->SYMBOL_SIGNATURE) {
            return
                "0x000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000035553420000000000000000000000000000000000000000000000000000000000";
        } else {
            return "0x0000000000000000000000000000000000000000000000000000000000000006";
        }
    });

my @received_transactions = $subscription_client->_check_plugins($transaction, $receipt->{result})->get;
is scalar @received_transactions, 1, "correct total transactions found";
is $received_transactions[0]->{currency}, 'USB', 'correct contract symbol';
is $received_transactions[0]->{to}, '0x2ae6d1401af58f9fbe2eda032b8494d519af5813', 'correct address `to`';
is $received_transactions[0]->{amount}->bstr(), Math::BigFloat->new(1000)->bstr, 'correct amount';
is $received_transactions[0]->{contract}, '0xdac17f958d2ee523a2206206994597c13d831ec7', 'correct contract address';

done_testing;
