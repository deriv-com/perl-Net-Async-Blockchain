#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;
use Test::MockModule;
use Net::Async::Blockchain::Transaction;
use Net::Async::Blockchain::Omni;
use Net::Async::Blockchain::BTC;
use Net::Async::Blockchain::Client::RPC::Omni;
use Net::Async::Blockchain::Client::RPC::BTC;

my $loop          = IO::Async::Loop->new();
my $currency_code = 'UST';

$loop->add(my $subscription_client = Net::Async::Blockchain::Omni->new(currency_symbol => $currency_code));

my $mocked_omni     = Test::MockModule->new('Net::Async::Blockchain::Omni');
my $mocked_rpc_omni = Test::MockModule->new('Net::Async::Blockchain::Client::RPC::Omni');

subtest "Omni Send " => sub {
    $loop->add(my $subscription_client = Net::Async::Blockchain::Omni->new(currency_symbol => $currency_code));

    my $expected_transaction = Net::Async::Blockchain::Transaction->new(
        currency     => $currency_code,
        hash         => '19e5bda81d0a588cbf46072fb6da01685a51082d4b94428e09f491ad8a111bc7',
        block        => '1666276',
        from         => 'mgVxUb5mYJkfoo4w2JBVBcWaP5bqtLroTr',
        to           => 'mvaK72Z5EVYJtptWrD2nCSZd1nqEx5B469',
        amount       => Math::BigFloat->new(21),
        fee          => Math::BigFloat->new(0.00000256),
        fee_currency => 'BTC',
        type         => 'sent',
        property_id  => 2147484941,
        timestamp    => 1582166123
    );

    $mocked_omni->mock(
        mapping_address => sub {
            my ($self, $omni_transaction) = @_;
            my ($from, $to);

            $from->{address} = 'mgVxUb5mYJkfoo4w2JBVBcWaP5bqtLroTr';
            $to->{address}   = 'mvaK72Z5EVYJtptWrD2nCSZd1nqEx5B469';

            return Future->done(($from, $to));
        });

    $mocked_rpc_omni->mock(
        list_by_addresses => sub {
            my ($self, $address) = @_;
            my $result;
            if ($address eq 'mgVxUb5mYJkfoo4w2JBVBcWaP5bqtLroTr') {
                $result = [{
                        txids   => ['1b007afef8d271861dccd5b6bfe2f7e45a481c9a2f39b9f063e43e7d26375ec7'],
                        address => 'mgVxUb5mYJkfoo4w2JBVBcWaP5bqtLroTr'
                    }];}

            else { $result = []; }
            
            return Future->done($result);
        },
        get_transaction => sub {
            my ($self, @params) = @_;
            my $omni_gettransaction = {
                blocktime        => 1582166123,
                confirmations    => 1,
                blockhash        => '00000000000b031f58f9761fd1e0219ef5178481f274b4f54d30c5142b97571f',
                block            => 1666276,
                type             => 'Simple Send',
                amount           => '21.00000000',
                divisible        => 1,
                fee              => '0.00000256',
                positioninblock  => 352,
                sendingaddress   => 'mgVxUb5mYJkfoo4w2JBVBcWaP5bqtLroTr',
                ismine           => 1,
                version          => 0,
                txid             => '19e5bda81d0a588cbf46072fb6da01685a51082d4b94428e09f491ad8a111bc7',
                type_int         => 0,
                referenceaddress => 'mvaK72Z5EVYJtptWrD2nCSZd1nqEx5B469',
                propertyid       => 2147484941,
                valid            => 1
            };

            return Future->done($omni_gettransaction);
        });

    my $decode_txn = {
        locktime => 1666275,
        txid     => '19e5bda81d0a588cbf46072fb6da01685a51082d4b94428e09f491ad8a111bc7',
        hex =>
            '0200000001582f14b201f7d54d57d440692d88195c49da305622e31a2ea814af325ddb15d0020000006a47304402204bf7f5712a74cf31e95b5bc6960d18dc8b5e90adbd05a69a7f63c859535b718202201deefe687d8dc73f51ad948926e220e3045ad354200d1cc88ad1f37b3dad364a012103e46ec48919aa92158f06a4a3e637424627db9ab14175fcc3625e8e7dc01b08cafeffffff030000000000000000166a146f6d6e69000000008000050d000000007d2b7500a0640100000000001976a9140ac7dc8728750a012754efe24cfc0e5166eab99388ac22020000000000001976a914a52c818037aac5aa436a4bb6b8bf3c2bf710c45788ace36c1900',
        block => 1666276,
        hash  => '19e5bda81d0a588cbf46072fb6da01685a51082d4b94428e09f491ad8a111bc7'
    };

    my $subscription_source = $subscription_client->source;
    $subscription_source->each(
        sub {
            my $transaction = shift;
            is $transaction->{currency}, 'UST',       'Currency code is correct';
            is $transaction->{amount},        "21",   'Amount is correct';
            is $transaction->{type},       'sent',   'Transaction Type is correct';
            is_deeply $transaction, $expected_transaction, "$currency_code Omni-Send Transaction is emitted correctly.";
            $subscription_source->finish();
        });

    my $emitted_transaction = $subscription_client->transform_transaction($decode_txn)->get();

    $mocked_omni->unmock_all();
    $mocked_rpc_omni->unmock_all();

};

subtest "Omni Send ALL" => sub {
    $loop->add(my $subscription_client = Net::Async::Blockchain::Omni->new(currency_symbol => $currency_code));

    my $expected_transaction = Net::Async::Blockchain::Transaction->new(
        currency     => $currency_code,
        hash         => '1b007afef8d271861dccd5b6bfe2f7e45a481c9a2f39b9f063e43e7d26375ec7',
        block        => Math::BigInt->new('1666293'),
        to           => 'mgVxUb5mYJkfoo4w2JBVBcWaP5bqtLroTr',
        from         => 'mvaK72Z5EVYJtptWrD2nCSZd1nqEx5B469',
        amount       => Math::BigFloat->new(56),
        fee          => Math::BigFloat->new(0.00000245),
        fee_currency => 'BTC',
        type         => 'receive',
        property_id  => 2147484941,
        timestamp    => 1582186008
    );

    $mocked_omni->mock(
        mapping_address => sub {
            my ($self, $omni_transaction) = @_;
            my ($from, $to);

            $to->{address}   = 'mgVxUb5mYJkfoo4w2JBVBcWaP5bqtLroTr';
            $from->{address} = 'mvaK72Z5EVYJtptWrD2nCSZd1nqEx5B469';

            return Future->done(($from, $to));
        });

    $mocked_rpc_omni->mock(
        list_by_addresses => sub {
            my ($self, $address) = @_;
            my $result;
            if ($address eq 'mgVxUb5mYJkfoo4w2JBVBcWaP5bqtLroTr') {
                $result = [{
                        txids   => ['19e5bda81d0a588cbf46072fb6da01685a51082d4b94428e09f491ad8a111bc7'],
                        address => 'mgVxUb5mYJkfoo4w2JBVBcWaP5bqtLroTr'}
                ]; }

            else { $result = []; }

            return Future->done($result);
        },
        get_transaction => sub {
            my ($self, @params) = @_;
            my $omni_gettransaction = {
                'confirmations' => 1,
                'version'       => 0,
                'type_int'      => 4,
                'subsends'      => [{
                        'amount'     => '56.00000000',
                        'propertyid' => 2147484941,
                        'divisible'  => 1
                    }
                ],
                'ecosystem'        => 'test',
                'positioninblock'  => 36,
                'type'             => 'Send All',
                'referenceaddress' => 'mgVxUb5mYJkfoo4w2JBVBcWaP5bqtLroTr',
                'ismine'           => 1,
                'block'            => 1666293,
                'fee'              => '0.00000245',
                'valid'            => 1,
                'blocktime'        => 1582186008,
                'sendingaddress'   => 'mvaK72Z5EVYJtptWrD2nCSZd1nqEx5B469',
                'blockhash'        => '0000000027072628ae58009d904e586cce12f2c68d3a501cbb0a781555bcb5d2',
                'txid'             => '1b007afef8d271861dccd5b6bfe2f7e45a481c9a2f39b9f063e43e7d26375ec7'
            };
            
            return Future->done($omni_gettransaction);
        });

    my $decode_txn = {
        'txid'     => '1b007afef8d271861dccd5b6bfe2f7e45a481c9a2f39b9f063e43e7d26375ec7',
        'weight'   => 980,
        'size'     => 245,
        'locktime' => 1666291,
        'version'  => 2,
        'vsize'    => 245,
        'hex' =>
            '0200000001402bb13ce021ae6a7c2d2cd6732ec8fe00f82cb4778df8faa981caf575de0bd8000000006a47304402201f2abeb6f9a9e48e1937d962c426ee392396c514785aeba2e7e7dd89886710a502202f69e903521db10686d24f7415d52de16f8983044821b92994ea81d7525cc0e9012102c404398448fdd4f3404212fd3e1c56d4ec17bfacbbe43d8c073e693fd406eb5bfeffffff0300000000000000000b6a096f6d6e69000000040222020000000000001976a9140ac7dc8728750a012754efe24cfc0e5166eab99388ac89830100000000001976a914a52c818037aac5aa436a4bb6b8bf3c2bf710c45788acf36c1900',
        'hash'  => '1b007afef8d271861dccd5b6bfe2f7e45a481c9a2f39b9f063e43e7d26375ec7',
        'block' => 1666293
    };

    my $subscription_source = $subscription_client->source;
    $subscription_source->each(
        sub {
            my $transaction = shift;
            is $transaction->{currency}, 'UST',       'Currency code is correct';
            is $transaction->{amount},        "56",   'Amount is correct';
            is $transaction->{type},       'receive',   'Transaction Type is correct';
            is_deeply $transaction, $expected_transaction, "$currency_code Omni-Send All Transaction is emitted correctly.";
            $subscription_source->finish();
        });

    my $emitted_transaction = $subscription_client->transform_transaction($decode_txn)->get();

    $mocked_omni->unmock_all();
    $mocked_rpc_omni->unmock_all();
};

done_testing();
