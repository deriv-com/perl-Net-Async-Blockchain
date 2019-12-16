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
my $plugin_utility = Net::Async::Blockchain::Plugins::ETH::Utility->new();

my $mock_rpc = Test::MockModule->new("Net::Async::Blockchain::Client::RPC::ETH");
my $mock_eth = Test::MockModule->new("Net::Async::Blockchain::ETH");

$mock_eth->mock(
    accounts => async sub {
        return ["0x1D8b942384c41Be24f202d458e819640E6f0218a"];
    });

my $received_transaction = $subscription_client->_set_transaction_type($transaction)->get;

is $received_transaction->{type}, 'receive', "valid transaction type for `to` address";

$mock_eth->mock(
    accounts => async sub {
        return ["0xe6c5De11DEc1aCda652BD7bF1E96fb56662E9f8F"];
    });

$received_transaction = $subscription_client->_set_transaction_type($transaction)->get;

is $received_transaction->{type}, 'sent', "valid transaction type for `from` address";

$mock_eth->mock(
    accounts => async sub {
        return ["0xe6c5De11DEc1aCda652BD7bF1E96fb56662E9f8F", "0x1D8b942384c41Be24f202d458e819640E6f0218a"];
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

$received_transaction = $subscription_client->_check_contract_transaction($transaction)->get;

is $received_transaction->{currency}, 'USB', 'correct contract symbol';
is $received_transaction->{to}, '0x2ae6d1401af58f9fbe2eda032b8494d519af5813', 'correct address `to`';
is $received_transaction->{amount}->bstr(), Math::BigFloat->new(1000)->bround(6)->bstr, 'correct amount';
is $received_transaction->{contract}, '0xdac17f958d2ee523a2206206994597c13d831ec7', 'correct contract address';

done_testing;
