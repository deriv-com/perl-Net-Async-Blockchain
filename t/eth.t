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

my $transaction = Net::Async::Blockchain::Transaction->new(
    currency     => 'ETH',
    hash         => '0x210850cef2c952387def5c40e23d7c8415e0abf2dd6ea0f5a9079f86b361dbae',
    block        => '8219294',
    from         => '0xe6c5de11dec1acda652bd7bf1e96fb56662e9f8f',
    to           => ['0x1d8b942384c41be24f202d458e819640e6f0218a'],
    contract     => '',
    amount       => 0.3292619388,
    fee          => 0.0004032,
    fee_currency => 'ETH',
    type         => '',
);

my $subscription_client = Net::Async::Blockchain::ETH->new();

my $mock_rpc = Test::MockModule->new("Net::Async::Blockchain::Client::RPC::ETH");
$mock_rpc->mock(
    accounts => async sub {
        return ["0x1D8b942384c41Be24f202d458e819640E6f0218a"];
    });

my $transactions    = $subscription_client->_set_transaction_type([$transaction])->get;
my @transactions_nr = $transactions->@*;

is $transactions_nr[0]->{type}, 'receive', "valid transaction type for `to` address";

$mock_rpc->mock(
    accounts => async sub {
        return ["0xe6c5De11DEc1aCda652BD7bF1E96fb56662E9f8F"];
    });

$transactions    = $subscription_client->_set_transaction_type([$transaction])->get;
@transactions_nr = $transactions->@*;

is $transactions_nr[0]->{type}, 'sent', "valid transaction type for `from` address";

$mock_rpc->mock(
    accounts => async sub {
        return ["0xe6c5De11DEc1aCda652BD7bF1E96fb56662E9f8F", "0x1D8b942384c41Be24f202d458e819640E6f0218a"];
    });

$transactions    = $subscription_client->_set_transaction_type([$transaction])->get;
@transactions_nr = $transactions->@*;

is $transactions_nr[0]->{type}, 'internal', "valid transaction type for `from` and `to` address";

$mock_rpc->mock(
    get_transaction_receipt => async sub {
        return {logs => []};
    });

$transactions    = $subscription_client->_check_contract_transaction($transaction)->get;
@transactions_nr = $transactions->@*;

is @transactions_nr, 1, "valid transactions after no contract found";

is $subscription_client->_remove_zeros("0x0f72a63496D0D5F17d3186750b65226201963716"), "0x0f72a63496D0D5F17d3186750b65226201963716",
    "no zeros to be removed";
is $subscription_client->_remove_zeros("0x000000000000000000000000000000000f72a63496D0D5F17d3186750b65226201963716"),
    "0x0f72a63496D0D5F17d3186750b65226201963716", "removes only not needed zeros";

$transaction = Net::Async::Blockchain::Transaction->new(
    currency     => 'ETH',
    hash         => '0x382dc93eae2df291bd5e885499778ac871babba3e2c5dcbf308be7c06be84739',
    block        => '8224186',
    from         => '0x0749c36df05f1ddb6cc0c797c94a676499191851',
    to           => ['0xdac17f958d2ee523a2206206994597c13d831ec7'],
    contract     => '',
    amount       => 0,
    fee          => 0.00023465,
    fee_currency => 'ETH',
    type         => '',
);

$mock_rpc->mock(
    get_transaction_receipt => async sub {
        return {
            logs => [{
                    address => "0xdac17f958d2ee523a2206206994597c13d831ec7",
                    topics  => [
                        "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
                        "0x0000000000000000000000000749c36df05f1ddb6cc0c797c94a676499191851",
                        "0x000000000000000000000000938534b724e7ea82da66f22eed82dd75bb486194"
                    ],
                    data => "0x000000000000000000000000000000000000000000000000000000001e3834c0"
                }
            ],
            status => "0x1"
        };
    },
    call => async sub {
        return
            "0x000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000035553420000000000000000000000000000000000000000000000000000000000";
    });

$transactions    = $subscription_client->_check_contract_transaction($transaction)->get;
@transactions_nr = $transactions->@*;

is @transactions_nr, 1, "valid transactions after no contract found";
is $transactions_nr[0]->{currency}, 'USB', 'correct contract symbol';
is $transactions_nr[0]->{to}[0], '0x938534b724e7ea82da66f22eed82dd75bb486194', 'correct address `to`';
is $transactions_nr[0]->{amount}->bstr(), 507000000, 'correct amount';
is $transactions_nr[0]->{contract}, '0xdac17f958d2ee523a2206206994597c13d831ec7', 'correct contract address';

done_testing;
