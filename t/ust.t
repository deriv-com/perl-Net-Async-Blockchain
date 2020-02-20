#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;
use Test::MockModule;
use Net::Async::Blockchain::Transaction;
use Net::Async::Blockchain::Omni;
use Net::Async::Blockchain::Client::RPC::Omni;

my $loop          = IO::Async::Loop->new();
my $currency_code = 'UST';

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
        get_block => sub {
            my $getblock = {

                'size'              => 106309,
                'version'           => 536870912,
                'height'            => 1666276,
                'chainwork'         => '00000000000000000000000000000000000000000000014281e3aa04f892428a',
                'nextblockhash'     => '000000005a804cb26e24bf2dd6ca0e4b7cbee1f42e3e3137a5bf83c88aad052d',
                'merkleroot'        => '3938838ee1d737923264ab996d27196d8706ab2b8c551f95ce2c8ddf4375d65c',
                'strippedsize'      => 62009,
                'hash'              => '00000000000b031f58f9761fd1e0219ef5178481f274b4f54d30c5142b97571f',
                'versionHex'        => '20000000',
                'previousblockhash' => '0000000000018d4e1629e4f9e138bc796bca82beb64373bc1a146344796571f0',
                'difficulty'        => 1,
                'confirmations'     => 22,
                'mediantime'        => 1582160015,
                'nonce'             => 1133657597,
                'weight'            => 292336,
                'nTx'               => 355,
                'tx'                => [{
                        'txid' => '19e5bda81d0a588cbf46072fb6da01685a51082d4b94428e09f491ad8a111bc7',
                        'hex' =>
                            '0200000001582f14b201f7d54d57d440692d88195c49da305622e31a2ea814af325ddb15d0020000006a47304402204bf7f5712a74cf31e95b5bc6960d18dc8b5e90adbd05a69a7f63c859535b718202201deefe687d8dc73f51ad948926e220e3045ad354200d1cc88ad1f37b3dad364a012103e46ec48919aa92158f06a4a3e637424627db9ab14175fcc3625e8e7dc01b08cafeffffff030000000000000000166a146f6d6e69000000008000050d000000007d2b7500a0640100000000001976a9140ac7dc8728750a012754efe24cfc0e5166eab99388ac22020000000000001976a914a52c818037aac5aa436a4bb6b8bf3c2bf710c45788ace36c1900',
                        'vsize'    => 256,
                        'size'     => 256,
                        'version'  => 2,
                        'locktime' => 1666275,
                        'hash'     => '19e5bda81d0a588cbf46072fb6da01685a51082d4b94428e09f491ad8a111bc7'
                    },
                    {
                        'txid'     => 'abd322cee71dbd9adbd8b200df4c69a7870251f73ec6e04a3eb5e9aa2b065bdf',
                        'locktime' => 0,
                        'hex' =>
                            '020000000203fdc4ea0591de6148363a8db7da8fb398bd3b1a84eb7d040aae787eb8acc690000000006a4730440220054a95f74fb2048a89e3e2a6961048a2a5539367f8f902083a38ac9b2afd458202206c9be9405bd12dfa0aa40c8ae299078bfd0730ea2d88f96850b169479cd9184f0121021f2a6cb7937966f4c2030e3817382ef0d2ab50482672a996a170528cda375bfcffffffff233d9e7e960adadc83c51413a6c77b705fc166804b9d23261cb49ccdbab68ba6020000006a473044022038ab0ddaaf35c989d9e7cf79a6538b54f96b4c1979960f060834ce98558a7ddc0220076632d3b468f7c24d6da0b8c7133bfdfb78ceac2340ac154d1bf304234d37b10121021f2a6cb7937966f4c2030e3817382ef0d2ab50482672a996a170528cda375bfcffffffff02b6140000000000001976a9140df9a2a1e8dd1ba5cb02bc2b3b67c8b7ba2f805088ac0000000000000000166a146f6d6e690000000000000001000000000098968000000000',
                        'vsize'   => 369,
                        'version' => 2,
                        'size'    => 369,
                        'hash'    => 'abd322cee71dbd9adbd8b200df4c69a7870251f73ec6e04a3eb5e9aa2b065bdf'
                    }

                ],
                'bits' => '1d00ffff',
                'time' => 1582166123
            };
            return Future->done($getblock);
        },
        list_by_addresses => sub {
            my ($self, $address) = @_;
            my $result;
            if ($address eq 'mgVxUb5mYJkfoo4w2JBVBcWaP5bqtLroTr') {
                $result = [{
                        txids   => ['1b007afef8d271861dccd5b6bfe2f7e45a481c9a2f39b9f063e43e7d26375ec7'],
                        address => 'mgVxUb5mYJkfoo4w2JBVBcWaP5bqtLroTr'
                    }];
            }

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

    my $subscription_source = $subscription_client->source;
    $subscription_source->each(
        sub {
            my $transaction = shift;
            is $transaction->{currency}, 'UST',  'Currency code is correct';
            is $transaction->{amount},   "21",   'Amount is correct';
            is $transaction->{type},     'sent', 'Transaction Type is correct';
            is_deeply $transaction, $expected_transaction, "$currency_code Omni-Send Transaction is emitted correctly.";
            $subscription_source->finish();
        });

    my $emitted_transaction = $subscription_client->hashblock('00000000000b031f58f9761fd1e0219ef5178481f274b4f54d30c5142b97571f')->get;

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
        get_block => sub {
            my $getblock = {
                'nonce'      => 2033938908,
                'chainwork'  => '00000000000000000000000000000000000000000000014282837e9ccb319e5c',
                'version'    => 536870912,
                'bits'       => '1d00ffff',
                'merkleroot' => '6f5bb0cbcb7fbe18cc32811b405d092f5e2ff57fbb5cb8e8123b7423b0dd2fc2',
                'hash'       => '0000000027072628ae58009d904e586cce12f2c68d3a501cbb0a781555bcb5d2',
                'weight'     => 48876,
                'height'     => 1666293,
                'time'       => 1582186008,
                'tx'         => [{
                        'txid'     => '1b007afef8d271861dccd5b6bfe2f7e45a481c9a2f39b9f063e43e7d26375ec7',
                        'weight'   => 980,
                        'locktime' => 1666291,
                        'hash'     => '1b007afef8d271861dccd5b6bfe2f7e45a481c9a2f39b9f063e43e7d26375ec7'
                    },
                    {
                        'txid'   => '056de597456300a4139f42ad4d8f7f2dd662ded515f314a29480af2e547b2bf5',
                        'vsize'  => 256,
                        'weight' => 1024
                    }
                ],
                'mediantime'        => 1582179927,
                'size'              => 12219,
                'difficulty'        => 1,
                'versionHex'        => '20000000',
                'nTx'               => 38,
                'previousblockhash' => '000000009ec12186d1406c6dbcdbb7714c9d8e7eb0c8f661c3df0966685ae226',
                'confirmations'     => 1,
                'strippedsize'      => 12219
            };

            return Future->done($getblock);
        },
        list_by_addresses => sub {
            my ($self, $address) = @_;
            my $result;
            if ($address eq 'mgVxUb5mYJkfoo4w2JBVBcWaP5bqtLroTr') {
                $result = [{
                        txids   => ['19e5bda81d0a588cbf46072fb6da01685a51082d4b94428e09f491ad8a111bc7'],
                        address => 'mgVxUb5mYJkfoo4w2JBVBcWaP5bqtLroTr'
                    }];
            }

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

    my $subscription_source = $subscription_client->source;
    $subscription_source->each(
        sub {
            my $transaction = shift;
            is $transaction->{currency}, 'UST',     'Currency code is correct';
            is $transaction->{amount},   "56",      'Amount is correct';
            is $transaction->{type},     'receive', 'Transaction Type is correct';
            is_deeply $transaction, $expected_transaction, "$currency_code Omni-Send All Transaction is emitted correctly.";
            $subscription_source->finish();
        });

    my $emitted_transaction = $subscription_client->hashblock('0000000027072628ae58009d904e586cce12f2c68d3a501cbb0a781555bcb5d2')->get;

    $mocked_omni->unmock_all();
    $mocked_rpc_omni->unmock_all();
};

done_testing();
