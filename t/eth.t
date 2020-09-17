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

my $mock_rpc = Test::MockModule->new("Net::Async::Blockchain::Client::RPC::ETH");
my $mock_eth = Test::MockModule->new("Net::Async::Blockchain::ETH");

$mock_eth->mock(
    accounts => sub {
        my %accounts = (lc "0x1D8b942384c41Be24f202d458e819640E6f0218a" => 1);
        return \%accounts;
    });

my $received_transaction = $subscription_client->_set_transaction_type($transaction)->get;

is $received_transaction->{type}, 'receive', "valid transaction type for `to` address";

$mock_eth->mock(
    accounts => sub {
        my %accounts = (lc "0xe6c5De11DEc1aCda652BD7bF1E96fb56662E9f8F" => 1);
        return \%accounts;
    });

$received_transaction = $subscription_client->_set_transaction_type($transaction)->get;

is $received_transaction->{type}, 'send', "valid transaction type for `from` address";

$mock_eth->mock(
    accounts => sub {
        my %accounts = (
            lc "0xe6c5De11DEc1aCda652BD7bF1E96fb56662E9f8F" => 1,
            lc "0x1D8b942384c41Be24f202d458e819640E6f0218a" => 1
        );
        return \%accounts;
    });

$received_transaction = $subscription_client->_set_transaction_type($transaction)->get;

is $received_transaction->{type}, 'internal', "valid transaction type for `from` and `to` address";

$mock_rpc->mock(
    get_transaction_receipt => async sub {
        return {logs => []};
    });

is $subscription_client->_remove_zeros("0x0f72a63496D0D5F17d3186750b65226201963716"), "0x0f72a63496D0D5F17d3186750b65226201963716",
    "no zeros to be removed";
is $subscription_client->_remove_zeros("0x000000000000000000000000000000000f72a63496D0D5F17d3186750b65226201963716"),
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
    decode_json_utf8(
    '{"jsonrpc":"2.0","id":1,"result":{"blockHash":"0x2e16030779d881acd4306aa7d00ba9a9177b0b28d9ef334b607ff47d712e558c","blockNumber":"0x7d7da1","contractAddress":null,"cumulativeGasUsed":"0x4e68a5","from":"0x32d038a19f75b2ba4ca1d38a82192ff353c47be2","gasUsed":"0x9601","logs":[{"address":"0xdac17f958d2ee523a2206206994597c13d831ec7","topics":["0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef","0x00000000000000000000000032d038a19f75b2ba4ca1d38a82192ff353c47be2","0x0000000000000000000000002ae6d1401af58f9fbe2eda032b8494d519af5813"],"data":"0x000000000000000000000000000000000000000000000000000000003b9aca00","blockNumber":"0x7d7da1","transactionHash":"0x382dc93eae2df291bd5e885499778ac871babba3e2c5dcbf308be7c06be84739","transactionIndex":"0x91","blockHash":"0x2e16030779d881acd4306aa7d00ba9a9177b0b28d9ef334b607ff47d712e558c","logIndex":"0x49","removed":false}],"logsBloom":"0x00000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000010000000000000000000020000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000400000000000000000000000100000000000000000000000000080000000000000000000000000000002000000000000000002000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000004","status":"0x1","to":"0xdac17f958d2ee523a2206206994597c13d831ec7","transactionHash":"0x382dc93eae2df291bd5e885499778ac871babba3e2c5dcbf308be7c06be84739","transactionIndex":"0x91"}}'
    );

$mock_rpc->mock(
    call => async sub {
        my ($self, $args) = @_;
        if ($args->{data} eq Net::Async::Blockchain::ETH->SYMBOL_SIGNATURE) {
            return
                "0x000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000035553420000000000000000000000000000000000000000000000000000000000";
        } else {
            return "0x0000000000000000000000000000000000000000000000000000000000000006";
        }
    });

my @received_transactions = $subscription_client->_check_contract_transaction($transaction, $receipt->{result})->get;
is scalar @received_transactions, 1, "correct total transactions found";
is $received_transactions[0]->{currency}, 'USB',                                        'correct contract symbol';
is $received_transactions[0]->{to},       '0x2ae6d1401af58f9fbe2eda032b8494d519af5813', 'correct address `to`';
is $received_transactions[0]->{amount}->bstr(), Math::BigFloat->new(1000)->bstr, 'correct amount';
is $received_transactions[0]->{contract}, '0xdac17f958d2ee523a2206206994597c13d831ec7', 'correct contract address';

$receipt = decode_json_utf8(
    '{"jsonrpc":"2.0","id":1,"result":{"blockHash":"0xf3284e85de5c9eb5199530d0c47b6006b5c480135975f72c352b4d12d16c9643","blockNumber":"0x897712","contractAddress":null,"cumulativeGasUsed":"0x7f613a","from":"0x65798e5c90a332bbfa37c793f8847c441df42d44","gasUsed":"0x5fb9","logs":[],"logsBloom":"0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000","status":"0x0","to":"0x72338b82800400f5488eca2b5a37270ba3b7a111","transactionHash":"0x1a7d89fcbba627f9c82ac8edcf93180c84a5ae754418589787a703ad4a974870","transactionIndex":"0x79"}}'
);

@received_transactions = $subscription_client->_check_contract_transaction($transaction, $receipt->{result})->get;
is scalar @received_transactions, 0, "invalid transaction filtered";

$receipt->{result}->{status} = "0x1";

@received_transactions = $subscription_client->_check_contract_transaction($transaction, $receipt->{result})->get;
is scalar @received_transactions, 0, "invalid transaction filtered even when the status is true";

$receipt->{result}->{logs} = decode_json_utf8(
    '[{"address":"0xdac17f958d2ee523a2206206994597c13d831ec7","topics":["0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef","0x00000000000000000000000032d038a19f75b2ba4ca1d38a82192ff353c47be2","0x0000000000000000000000002ae6d1401af58f9fbe2eda032b8494d519af5813"],"data":"0x000000000000000000000000000000000000000000000000000000003b9aca00","blockNumber":"0x7d7da1","transactionHash":"0x382dc93eae2df291bd5e885499778ac871babba3e2c5dcbf308be7c06be84739"}]'
);

$mock_rpc->mock(
    call => async sub {
        my ($self, $args) = @_;
        if ($args->{data} eq Net::Async::Blockchain::ETH->SYMBOL_SIGNATURE) {
            return
                "0x000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000035553420000000000000000000000000000000000000000000000000000000000";
        } else {
            return
                "0x08c379a00000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000001853656e646572206973206e6f74206120636f6e74726163740000000000000000";
        }
    });

@received_transactions = $subscription_client->_check_contract_transaction($transaction, $receipt->{result})->get;
is scalar @received_transactions, 0, "invalid transaction filtered when the decimals are bigger not equals to 64 characters";

$receipt = decode_json_utf8(
    '{"jsonrpc":"2.0","id":1,"result":{"blockHash":"0xf3284e85de5c9eb5199530d0c47b6006b5c480135975f72c352b4d12d16c9643","blockNumber":"0x897712","contractAddress":null,"cumulativeGasUsed":"0x88e12d","from":"0x0e98727a9f30bd3083dc8926ffa3456cc74e93b0","gasUsed":"0x394ae","logs":[{"address":"0x61646f3bede9e1a24d387feb661888b4cc1587d8","topics":["0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef","0x0000000000000000000000000e98727a9f30bd3083dc8926ffa3456cc74e93b0","0x00000000000000000000000073e44092b5a886a37bea74bfc90911d0c98f6a15"],"data":"0x00000000000000000000000000000000000000000000002567ac70392b880000","blockNumber":"0x897712","transactionHash":"0x1225049616c8dd5f88b6f68020a1572bba3e3e72f872d5e838a47919b98339bd","transactionIndex":"0x81","blockHash":"0xf3284e85de5c9eb5199530d0c47b6006b5c480135975f72c352b4d12d16c9643","logIndex":"0xba","removed":false},{"address":"0x73e44092b5a886a37bea74bfc90911d0c98f6a15","topics":["0x8c41d101e4d957423a65fda82dcc88bc6b3e756166d2331f663c10166658ebb8","0x0000000000000000000000000e98727a9f30bd3083dc8926ffa3456cc74e93b0"],"data":"0x","blockNumber":"0x897712","transactionHash":"0x1225049616c8dd5f88b6f68020a1572bba3e3e72f872d5e838a47919b98339bd","transactionIndex":"0x81","blockHash":"0xf3284e85de5c9eb5199530d0c47b6006b5c480135975f72c352b4d12d16c9643","logIndex":"0xbb","removed":false},{"address":"0xae38c27e646959735ec70d77ed4ecc03a3eff490","topics":["0xf5122232b588fd8926743beb8e1ce73bb77585b17da27b759a60596bcb80e416","0x00000000000000000000000073e44092b5a886a37bea74bfc90911d0c98f6a15","0x000000000000000000000000a823e6722006afe99e91c30ff5295052fe6b8e32"],"data":"0x921c3afa1f1fff707a785f953a1e197bd28c9c50e300424e015953cbf120c06c9260faf8000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001","blockNumber":"0x897712","transactionHash":"0x1225049616c8dd5f88b6f68020a1572bba3e3e72f872d5e838a47919b98339bd","transactionIndex":"0x81","blockHash":"0xf3284e85de5c9eb5199530d0c47b6006b5c480135975f72c352b4d12d16c9643","logIndex":"0xbc","removed":false},{"address":"0xa823e6722006afe99e91c30ff5295052fe6b8e32","topics":["0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef","0x0000000000000000000000000000000000000000000000000000000000000000","0x00000000000000000000000073e44092b5a886a37bea74bfc90911d0c98f6a15"],"data":"0x0000000000000000000000000000000000000000000000e76b2de77ddb153d51","blockNumber":"0x897712","transactionHash":"0x1225049616c8dd5f88b6f68020a1572bba3e3e72f872d5e838a47919b98339bd","transactionIndex":"0x81","blockHash":"0xf3284e85de5c9eb5199530d0c47b6006b5c480135975f72c352b4d12d16c9643","logIndex":"0xbd","removed":false},{"address":"0xa823e6722006afe99e91c30ff5295052fe6b8e32","topics":["0xc692d9de9c1139b24231001c9b58c13d754c6fb33a10aac08eca93b9dc65ff99","0x00000000000000000000000073e44092b5a886a37bea74bfc90911d0c98f6a15"],"data":"0x00000000000000000000000000000000000000000000002567ac70392b8800000000000000000000000000000000000000000000000000e76b2de77ddb153d51","blockNumber":"0x897712","transactionHash":"0x1225049616c8dd5f88b6f68020a1572bba3e3e72f872d5e838a47919b98339bd","transactionIndex":"0x81","blockHash":"0xf3284e85de5c9eb5199530d0c47b6006b5c480135975f72c352b4d12d16c9643","logIndex":"0xbe","removed":false},{"address":"0x535bfaeb50580f674bd2e076d6073adf28a46fa8","topics":["0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef","0x0000000000000000000000000000000000000000000000000000000000000000","0x00000000000000000000000073e44092b5a886a37bea74bfc90911d0c98f6a15"],"data":"0x00000000000000000000000000000000000000000000000000000000000010a6","blockNumber":"0x897712","transactionHash":"0x1225049616c8dd5f88b6f68020a1572bba3e3e72f872d5e838a47919b98339bd","transactionIndex":"0x81","blockHash":"0xf3284e85de5c9eb5199530d0c47b6006b5c480135975f72c352b4d12d16c9643","logIndex":"0xbf","removed":false},{"address":"0x535bfaeb50580f674bd2e076d6073adf28a46fa8","topics":["0xe1d005ce03271afee8eb8f3366ca27942bedc8c4be0e488f34b464524b59f824","0x00000000000000000000000073e44092b5a886a37bea74bfc90911d0c98f6a15"],"data":"0x0000000000000000000000001c4b7282cce720cb184c3365bb6b9f75e332bdd800000000000000000000000000000000000000000000000000000000000010a6","blockNumber":"0x897712","transactionHash":"0x1225049616c8dd5f88b6f68020a1572bba3e3e72f872d5e838a47919b98339bd","transactionIndex":"0x81","blockHash":"0xf3284e85de5c9eb5199530d0c47b6006b5c480135975f72c352b4d12d16c9643","logIndex":"0xc0","removed":false},{"address":"0x73e44092b5a886a37bea74bfc90911d0c98f6a15","topics":["0x1944d622008ee7d083888039644437ec03dde7f81821e6293c9a7f5c143daf60","0x0000000000000000000000000e98727a9f30bd3083dc8926ffa3456cc74e93b0"],"data":"0x0000000000000000000000000e98727a9f30bd3083dc8926ffa3456cc74e93b000000000000000000000000061646f3bede9e1a24d387feb661888b4cc1587d800000000000000000000000000000000000000000000002567ac70392b88000000000000000000000000000000000000000000000000002567ac70392b88000000000000000000000000000000000000000000000000000000000000000010a6000000000000000000000000535bfaeb50580f674bd2e076d6073adf28a46fa8000000000000000000000000000000000000000000000073b596f3beed8a9ea8","blockNumber":"0x897712","transactionHash":"0x1225049616c8dd5f88b6f68020a1572bba3e3e72f872d5e838a47919b98339bd","transactionIndex":"0x81","blockHash":"0xf3284e85de5c9eb5199530d0c47b6006b5c480135975f72c352b4d12d16c9643","logIndex":"0xc1","removed":false}],"logsBloom":"0x00000000000000000000000000000000001000000000800104008000000000000000000400400040000000000000002000000000020000000801000008004000000000000000000400800008002000000000000000000000000000400000000000010000020010000000000002000800200010000000000000000014000000000008000400000000000000000000000080000080000000000000001000000000000000000000000800000000000000000000000000000084000400000000000000000202000000000000000200000000000000000000000000000000000820000000000000000000000100000080000000000000000000000020000000000000","status":"0x1","to":"0x61646f3bede9e1a24d387feb661888b4cc1587d8","transactionHash":"0x1225049616c8dd5f88b6f68020a1572bba3e3e72f872d5e838a47919b98339bd","transactionIndex":"0x81"}}'
);

$mock_rpc->mock(
    call => async sub {
        my ($self, $args) = @_;
        if ($args->{data} eq Net::Async::Blockchain::ETH->SYMBOL_SIGNATURE) {
            if ($args->{to} eq "0x61646f3bede9e1a24d387feb661888b4cc1587d8") {
                return
                    "0x000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000054555522d54000000000000000000000000000000000000000000000000000000";
            } elsif ($args->{to} eq "0xa823e6722006afe99e91c30ff5295052fe6b8e32") {
                return
                    "0x000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000034e45550000000000000000000000000000000000000000000000000000000000";
            } elsif ($args->{to} eq "0x535bfaeb50580f674bd2e076d6073adf28a46fa8") {
                return
                    "0x000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000034752500000000000000000000000000000000000000000000000000000000000";
            }
        } else {
            if ($args->{to} eq "0x61646f3bede9e1a24d387feb661888b4cc1587d8") {
                return "0x0000000000000000000000000000000000000000000000000000000000000012";
            } elsif ($args->{to} eq "0xa823e6722006afe99e91c30ff5295052fe6b8e32") {
                return "0x0000000000000000000000000000000000000000000000000000000000000012";
            } elsif ($args->{to} eq "0x535bfaeb50580f674bd2e076d6073adf28a46fa8") {
                return "0x0000000000000000000000000000000000000000000000000000000000000000";
            }
        }
    });

@received_transactions = $subscription_client->_check_contract_transaction($transaction, $receipt->{result})->get;
is scalar @received_transactions, 3, "correct total transactions found";

is $received_transactions[0]->{currency}, 'EUR-T',                                      'correct contract symbol';
is $received_transactions[0]->{to},       '0x73e44092b5a886a37bea74bfc90911d0c98f6a15', 'correct address `to`';
is $received_transactions[0]->{amount}->bstr(), Math::BigFloat->new(690)->bstr, 'correct amount';
is $received_transactions[0]->{contract}, '0x61646f3bede9e1a24d387feb661888b4cc1587d8', 'correct contract address';

is $received_transactions[1]->{currency}, 'NEU',                                        'correct contract symbol';
is $received_transactions[1]->{to},       '0x73e44092b5a886a37bea74bfc90911d0c98f6a15', 'correct address `to`';
is $received_transactions[1]->{amount}->bstr(), Math::BigFloat->new("4268.920964490649222481")->bstr, 'correct amount';
is $received_transactions[1]->{contract}, '0xa823e6722006afe99e91c30ff5295052fe6b8e32', 'correct contract address';

is $received_transactions[2]->{currency}, 'GRP',                                        'correct contract symbol';
is $received_transactions[2]->{to},       '0x73e44092b5a886a37bea74bfc90911d0c98f6a15', 'correct address `to`';
is $received_transactions[2]->{amount}->bstr(), Math::BigFloat->new(4262)->bstr, 'correct amount';
is $received_transactions[2]->{contract}, '0x535bfaeb50580f674bd2e076d6073adf28a46fa8', 'correct contract address';

my @accounts =
    ("0xa823e6722006afe99e91c30ff5295052fe6b8e32", "0x61646f3bede9e1a24d387feb661888b4cc1587d8", "0x535bfaeb50580f674bd2e076d6073adf28a46fa8");

$mock_eth->unmock_all();
$mock_rpc->unmock_all();

$mock_rpc->mock(
    accounts => async sub {
        my ($self, $args) = @_;
        return \@accounts;
    });

$subscription_client->{accounts} = undef;
$subscription_client->get_hash_accounts()->get;
my $received_accounts = $subscription_client->accounts();

my %account_hash = $received_accounts->%*;

is scalar keys %account_hash, 3, "all accounts found in the hash";

for my $account (@accounts) {
    ok $account_hash{$account}, "account received ok: $account";
    delete $account_hash{$account};
}

is scalar keys %account_hash, 0, "no accounts left in the hash";

is $subscription_client->get_numeric_from_hex(
    "0x08c379a00000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000001853656e646572206973206e6f74206120636f6e74726163740000000000000000"
), undef, "Not a numeric hexadecimal";

is $subscription_client->get_numeric_from_hex("0x0000000000000000000000000000000000000000000000000000000000000012"), Math::BigFloat->new(18),
    "Correct numeric hexadecimal";

is $subscription_client->get_numeric_from_hex("0x0000000000000000000000000000000000000000000000000000000000000000"), Math::BigFloat->new(0),
    "Zero ok";

my $decoded_transaction = {
    'value'     => '0x0',
    'blockHash' => '0x50d00d90de21af946d7f22ed8709650835a33fdc4ad7bd13301e828a63959fc1',
    'gas'       => '0x8fd0',
    'to'        => '0xb0399c2fb7958d8d0fde93ec58c4efa1ba501375',
    'input' =>
        '0xa9059cbb0000000000000000000000000e0b9d8c9930e7cff062dd4a2b26bce95a0defeeffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
    'transactionIndex' => '0xd5',
    'r'                => '0xe78ad76ab429385d008aec23c56c3939cd375177a8e978e5484ac85a4d14af8e',
    'nonce'            => '0x126',
    's'                => '0x19b311a70300d546d65289a8f6073e8ba1b4b8bdfa088445ad1a4543501f3537',
    'hash'             => '0x480e83579318c5ab25d3bc6e9a9d89de9117e8c862d30779337c48bc8108f5b4',
    'blockNumber'      => '0x9831d1',
    'gasPrice'         => '0x4e3b29200',
    'from'             => '0x0e0b9d8c9930e7cff062dd4a2b26bce95a0defee',
    'v'                => '0x26'
};

my $amount = Math::BigFloat->from_hex($decoded_transaction->{value})->bdiv(10**18)->bround(18);
my $block  = Math::BigInt->from_hex($decoded_transaction->{blockNumber});

$transaction = Net::Async::Blockchain::Transaction->new(
    currency     => "ETH",
    hash         => $decoded_transaction->{hash},
    block        => $block,
    from         => $decoded_transaction->{from},
    to           => $decoded_transaction->{to},
    contract     => '',
    amount       => $amount,
    fee          => 0.00021,
    fee_currency => "ETH",
    type         => '',
    data         => $decoded_transaction->{input},
    timestamp    => 0,
);

$receipt = decode_json_utf8(
    '{"jsonrpc":"2.0","id":1,"result":{"blockHash":"0x50d00d90de21af946d7f22ed8709650835a33fdc4ad7bd13301e828a63959fc1","blockNumber":"0x9831d1","contractAddress":null,"cumulativeGasUsed":"0x8bdf44","from":"0x0e0b9d8c9930e7cff062dd4a2b26bce95a0defee","gasUsed":"0x5fe0","logs":[{"address":"0xb0399c2fb7958d8d0fde93ec58c4efa1ba501375","blockHash":"0x50d00d90de21af946d7f22ed8709650835a33fdc4ad7bd13301e828a63959fc1","blockNumber":"0x9831d1","data":"0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","logIndex":"0xa0","removed":false,"topics":["0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef","0x0000000000000000000000000e0b9d8c9930e7cff062dd4a2b26bce95a0defee","0x0000000000000000000000000e0b9d8c9930e7cff062dd4a2b26bce95a0defee"],"transactionHash":"0x480e83579318c5ab25d3bc6e9a9d89de9117e8c862d30779337c48bc8108f5b4","transactionIndex":"0xd5"}],"logsBloom":"0x00000000000000000000000000000000000000000000000000000008000000000000000000000000000000008000000080000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008002000000000000000000000000000000000000800000000000000000000200000000000000000000000000000000000000000000000000000000000000","status":"0x1","to":"0xb0399c2fb7958d8d0fde93ec58c4efa1ba501375","transactionHash":"0x480e83579318c5ab25d3bc6e9a9d89de9117e8c862d30779337c48bc8108f5b4","transactionIndex":"0xd5"}}'
);

$mock_rpc->mock(
    call => async sub {
        my ($self, $args) = @_;
        if ($args->{data} eq Net::Async::Blockchain::ETH->SYMBOL_SIGNATURE) {
            return
                "0x000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000034e45550000000000000000000000000000000000000000000000000    000000000";
        } else {
            return "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff";
        }
    });

my $result = $subscription_client->_check_contract_transaction($transaction, $receipt->{result})->get;
is $result, undef;

$mock_rpc->mock(
    call => async sub {
        my ($self, $args) = @_;
        if ($args->{data} eq Net::Async::Blockchain::ETH->SYMBOL_SIGNATURE) {
            return
                "0x000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000034e45550000000000000000000000000000000000000000000000000    000000000";
        } else {
            return "0x0000000000000000000000000000000000000000000000000000000000000012";
        }
    });

@received_transactions = $subscription_client->_check_contract_transaction($transaction, $receipt->{result})->get;
is scalar @received_transactions, 1, "correct total transactions found";

is $received_transactions[0]->{to}, '0x0e0b9d8c9930e7cff062dd4a2b26bce95a0defee', 'correct address `to`';
is $received_transactions[0]->{amount}->bstr(),
    Math::BigFloat->new("115792089237316195423570985008687907853269984665640564039457584007913129639935")->bdiv(Math::BigInt->new(10)->bpow(18))
    ->bstr, 'correct amount converted to 18 decimal places';
is $received_transactions[0]->{contract}, '0xb0399c2fb7958d8d0fde93ec58c4efa1ba501375', 'correct contract address';

done_testing;
