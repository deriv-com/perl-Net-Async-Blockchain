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

my $transactions = $subscription_client->_set_transaction_type([$transaction])->get;
my @transactions_nr = $transactions->@*;

is $transactions_nr[0]->{type}, 'receive', "valid transaction type for `to` address";

$mock_rpc->mock(
    accounts => async sub {
        return ["0xe6c5De11DEc1aCda652BD7bF1E96fb56662E9f8F"];
    });

$transactions = $subscription_client->_set_transaction_type([$transaction])->get;
@transactions_nr = $transactions->@*;

is $transactions_nr[0]->{type}, 'sent', "valid transaction type for `from` address";

$mock_rpc->mock(
    accounts => async sub {
        return ["0xe6c5De11DEc1aCda652BD7bF1E96fb56662E9f8F", "0x1D8b942384c41Be24f202d458e819640E6f0218a"];
    });

$transactions = $subscription_client->_set_transaction_type([$transaction])->get;
@transactions_nr = $transactions->@*;

is $transactions_nr[0]->{type}, 'internal', "valid transaction type for `from` and `to` address";

$mock_rpc->mock(
    get_transaction_receipt => async sub {
        return {logs => []};
    });

$transactions = $subscription_client->_check_contract_transaction($transaction)->get;
@transactions_nr = $transactions->@*;

is @transactions_nr, 1, "valid transactions after no contract found";

is $subscription_client->_remove_zeros("0x0f72a63496D0D5F17d3186750b65226201963716"), "0x0f72a63496D0D5F17d3186750b65226201963716", "no zeros to be removed";
is $subscription_client->_remove_zeros("0x000000000000000000000000000000000f72a63496D0D5F17d3186750b65226201963716"), "0x0f72a63496D0D5F17d3186750b65226201963716", "removes only not needed zeros";

done_testing;

