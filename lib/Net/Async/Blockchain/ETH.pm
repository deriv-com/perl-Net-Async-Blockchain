package Net::Async::Blockchain::ETH;

use strict;
use warnings;

our $VERSION = '0.001';

=head1 NAME

Net::Async::Blockchain::ETH - Ethereum based subscription.

=head1 SYNOPSIS

    my $eth_args = { subscription_url => "ws://127.0.0.1:8546", rpc_url => "http://127.0.0.1:8545" };

    my $loop = IO::Async::Loop->new;

    $loop->add(
        my $eth_client = Net::Async::Blockchain::ETH->new(
            config => $eth_args
        )
    );

    $eth_client->subscribe("transactions")->each(sub { print shift->{hash} })->get;

=head1 DESCRIPTION

Ethereum subscription using websocket node client

=over 4

=back

=cut

no indirect;

use Future::AsyncAwait;
use Ryu::Async;
use JSON::MaybeUTF8 qw(decode_json_utf8 encode_json_utf8);
use Math::BigInt;
use Math::BigFloat;
use Digest::Keccak qw(keccak_256_hex);
use Syntax::Keyword::Try;

use Net::Async::Blockchain::Transaction;
use Net::Async::Blockchain::Client::RPC::ETH;
use Net::Async::Blockchain::Client::Websocket;
use Net::Async::Blockchain::TP::API::ETH;

use parent qw(Net::Async::Blockchain);

use constant {
    TRANSFER_EVENT_SIGNATURE => '0x' . keccak_256_hex('Transfer(address,address,uint256)'),
    SYMBOL_SIGNATURE         => '0x' . keccak_256_hex('symbol()'),
    DECIMALS_SIGNATURE       => '0x' . keccak_256_hex('decimals()'),
    DEFAULT_CURRENCY         => 'ETH',
    DEFAULT_DECIMAL_PLACES   => 18,
    UPDATE_ACCOUNTS          => 10,
};

my %subscription_dictionary = ('transactions' => 'newHeads');

sub currency_symbol : method { shift->{currency_symbol} // DEFAULT_CURRENCY }

=head2 subscription_id

Actual subscription ID, this ID is received every time when a subscription
is created.

=over 4

=back

An hexadecimal string

=cut

sub subscription_id { shift->{subscription_id} }

=head2 accounts

return the blockchain accounts, if is the first time will call eth_accounts.

=over 4

=back

returns a Future, the on_done response will be the accounts array.

=cut

sub accounts {
    my $self = shift;
    return $self->{accounts};
}

=head2 latest_accounts_update

stores the time of the latest account update

=over 4

=back

Returns L<time> of the latest account update

=cut

sub latest_accounts_update : method {
    my ($self) = @_;
    return $self->{latest_accounts_update};
}

=head2 get_hash_accounts

Request the node accounts and convert it to a hash

=over 4

=back

hash ref containing the accounts as keys

=cut

async sub get_hash_accounts {
    my ($self) = @_;

    $self->{latest_accounts_update} = time;
    my $accounts_response = await $self->rpc_client->accounts();
    my %accounts = map { lc($_) => 1 } $accounts_response->@*;
    $self->{accounts} = \%accounts;
    return $self->{accounts};
}

=head2 rpc_client

Create an L<Net::Async::Blockchain::Client::RPC> instance, if it is already defined just return
the object

=over 4

=back

L<Net::Async::Blockchain::Client::RPC>

=cut

sub rpc_client : method {
    my ($self) = @_;
    return $self->{rpc_client} //= do {
        $self->add_child(
            my $http_client = Net::Async::Blockchain::Client::RPC::ETH->new(
                endpoint => $self->rpc_url,
                timeout  => $self->rpc_timeout
            ));
        $http_client;
    };
}

=head2 new_websocket_client

Create a new async websocket client.

=over 4

=back

L<Net::Async::Blockchain::Client::Websocket>

=cut

sub new_websocket_client {
    my ($self) = @_;
    $self->add_child(
        my $client = Net::Async::Blockchain::Client::Websocket->new(
            endpoint    => $self->subscription_url,
            on_shutdown => sub {
                my ($error) = @_;
                warn $error;
                # finishes the final client source
                $self->source->finish();
            }));
    return $client;
}

=head2 tp_api

Create an L<Net::Async::Blockchain::TP::API::ETH> instance, if it is already defined just return
the object

=over 4

=back

L<Net::Async::Blockchain::TP::API::ETH>

=cut

sub tp_api : method {
    my ($self) = @_;
    return $self->{tp_api} //= do {
        $self->add_child(my $api_client = Net::Async::Blockchain::TP::API::ETH->new(tp_api_config => $self->{tp_api_config}));
        $api_client;
    };
}

=head2 subscribe

Connect to the websocket port and subscribe to the implemented subscription:
- https://github.com/ethereum/go-ethereum/wiki/RPC-PUB-SUB#create-subscription

=over 4

=item * C<subscription> string subscription name

=back

L<Ryu::Source>

=cut

sub subscribe {
    my ($self, $subscription) = @_;

    # rename the subscription to the correct blockchain node subscription
    $subscription = $subscription_dictionary{$subscription};

    die "Invalid or not implemented subscription" unless $subscription && $self->can($subscription);

    Future->needs_all(
        $self->new_websocket_client()->eth_subscribe($subscription)
            # the first response from the node is the subscription id
            # once we received it we can start to listening the subscription.
            ->skip_until(
            sub {
                my $response = shift;
                return 1 unless $response->{result};
                $self->{subscription_id} = $response->{result} unless $self->{subscription_id};
                return 0;
            })
            # we use the subscription id received as the first response to filter
            # all incoming subscription responses.
            ->filter(
            sub {
                my $response = shift;
                return undef unless $response->{params} && $response->{params}->{subscription};
                return $response->{params}->{subscription} eq $self->subscription_id;
            }
            )->map(
            async sub {
                await $self->$subscription(shift);
            }
            )->ordered_futures->completed(),
        $self->recursive_search(),
        )->on_fail(
        sub {
            $self->source->fail(@_);
        })->retain;

    return $self->source;
}

=head2 recursive_search

go into each block starting from the C<base_block_number> searching
for transactions from the node, this is usually needed when you stop
the subscription and need to check the blocks since the last one that
you received.

=over 4

=back

=cut

async sub recursive_search {
    my ($self) = @_;

    return undef unless $self->base_block_number;

    my $current_block = Math::BigInt->from_hex(await $self->rpc_client->get_last_block());

    # the node will return empty for the block number when it's not synced
    die "Node is not synced" unless $current_block && $current_block->bgt(0);

    while (1) {
        last unless $current_block->bgt($self->base_block_number);
        await $self->newHeads({params => {result => {number => sprintf("0x%X", $self->base_block_number)}}});
        $self->{base_block_number}++;
    }
}

=head2 newHeads

newHeads subscription

Convert and emit one or more L<Net::Async::Blockchain::Transaction> for the client
source every new block received that contains transactions owned by the node.

=over 4

=item * C<block> new block received with the transactions

=back

=cut

async sub newHeads {
    my ($self, $response) = @_;

    my $block = $response->{params}->{result};

    my $block_response = await $self->rpc_client->get_block_by_number($block->{number}, \1);

    # block not found or some issue in the RPC call
    unless ($block_response) {
        warn sprintf("%s: Can't reach response for block %s", $self->currency_symbol, Math::BigInt->from_hex($block->{number})->bstr);
        return undef;
    }

    my @transactions = $block_response->{transactions}->@*;
    for my $transaction (@transactions) {
        await $self->transform_transaction($transaction, $block_response->{timestamp});
    }

    return 1;
}

=head2 transform_transaction

Receive a decoded transaction and convert it to a list of L<Net::Async::Blockchain::Transaction>
once converted it emits all transactions to the client source.

=over 4

=item * C<decoded_transaction> the format here will be the same as the response from the command `getTransactionByHash`

=back

=cut

async sub transform_transaction {
    my ($self, $decoded_transaction, $timestamp) = @_;

    # Contract creation transactions.
    return undef unless $decoded_transaction->{to};

    # - received: `0x49f0421a52800`
    # - hex conversion: 1300740000000000
    # - 1300740000000000 * 10**18 = 0.0013007400000000000
    my $amount        = Math::BigFloat->from_hex($decoded_transaction->{value})->bdiv(10**DEFAULT_DECIMAL_PLACES)->bround(DEFAULT_DECIMAL_PLACES);
    my $block         = Math::BigInt->from_hex($decoded_transaction->{blockNumber});
    my $int_timestamp = Math::BigInt->from_hex($timestamp)->numify;

    my $transaction;

    try {
        my $gas          = $decoded_transaction->{gas};
        my $receipt      = await $self->rpc_client->get_transaction_receipt($decoded_transaction->{hash});
        my $address_code = await $self->rpc_client->get_code($decoded_transaction->{to}, 'latest');

        $gas = $receipt->{gasUsed} if $receipt && $receipt->{gasUsed};

        # if the gas is empty we don't proceed
        return 0 unless $gas && $decoded_transaction->{gasPrice};

        # fee = gas * gasPrice
        my $fee = Math::BigFloat->from_hex($gas)->bmul($decoded_transaction->{gasPrice});

        $transaction = Net::Async::Blockchain::Transaction->new(
            currency     => $self->currency_symbol,
            hash         => $decoded_transaction->{hash},
            block        => $block,
            from         => $decoded_transaction->{from},
            to           => $decoded_transaction->{to},
            contract     => '',
            amount       => $amount,
            fee          => $fee,
            fee_currency => $self->currency_symbol,
            type         => '',
            data         => $decoded_transaction->{input},
            timestamp    => $int_timestamp,
        );

        my @transactions;
        if ($address_code ne '0x') {
            my @contract_transaction = await $self->_check_contract_transaction($transaction, $receipt);
            my @internal_transaction = await $self->_check_internal_transaction($transaction);
            push(@transactions, @contract_transaction);
            push(@transactions, @internal_transaction);
        }
        push(@transactions, $transaction);

        if (!$self->accounts() || ($self->latest_accounts_update + UPDATE_ACCOUNTS <= time)) {
            await $self->get_hash_accounts();
        }

        for my $tx (@transactions) {
            # set the type for each transaction
            # from and to => internal
            # to => received
            # from => sent
            my $tx_type_response = await $self->_set_transaction_type($tx);
            $self->source->emit($tx_type_response) if $tx_type_response;
        }

    }
    catch {
        my $err = $@;
        warn sprintf("Error processing transaction: %s, error: %s", $decoded_transaction->{hash}, $err);
        return 0;
    }

    return 1;
}

=head2 _set_transaction_type

To identify what are the transactions that are owned by the node
we need to check our list of addresses and compare it with each transaction
the result will be:

if to and from found: internal
if to found: receive
if from found: sent

=over 4

=item * array of L<Net::Async::Blockchain::Transaction>

=back

hashref from an array of L<Net::Async::Blockchain::Transaction>

=cut

async sub _set_transaction_type {
    my ($self, $transaction) = @_;

    return undef unless $transaction;

    my $accounts = $self->accounts();
    return undef unless $accounts;

    my $from = $accounts->{lc($transaction->from)};
    my $to   = $accounts->{lc($transaction->to)};

    if ($from && $to) {
        $transaction->{type} = 'internal';
    } elsif ($from) {
        $transaction->{type} = 'sent';
    } elsif ($to) {
        $transaction->{type} = 'receive';
    }

    return $transaction->type ? $transaction : undef;
}

=head2 _check_contract_transaction

For now this method just check the ERC20 contracts

=over 4

=item * C<$client> - a L<Net::Async::Blockchain::ETH> instance

=back

Returns an array of hashrefs with fields matching attributes in L<Net::Async::Blockchain::Transaction>

=cut

async sub _check_contract_transaction {
    my ($self, $transaction, $receipt) = @_;

    my $logs = $receipt->{logs};

    return () unless $logs && @$logs;

    my @transactions;

    return () unless $receipt->{status} && hex($receipt->{status}) == 1;

    for my $log ($logs->@*) {
        my @topics = $log->{topics}->@*;
        if (@topics && $topics[0] eq TRANSFER_EVENT_SIGNATURE) {
            my $transaction_cp = $transaction->clone();

            my $address = $log->{address};
            my $amount  = $self->get_numeric_from_hex($log->{data});
            next unless $amount;

            my $hex_symbol = await $self->rpc_client->call({
                    data => SYMBOL_SIGNATURE,
                    to   => $address
                },
                "latest"
            );

            my $symbol = $self->_to_string($hex_symbol);
            next unless $symbol;

            $transaction_cp->{currency} = $symbol;

            my $decimals = await $self->rpc_client->call({
                    data => DECIMALS_SIGNATURE,
                    to   => $address
                },
                "latest"
            );

            if ($decimals) {
                my $bg_decimals = $self->get_numeric_from_hex($decimals);
                # decimals can be 0 is that why we check by reference
                next unless eval { $bg_decimals->isa('Math::BigFloat') };
                $transaction_cp->{amount} = $amount->bdiv(Math::BigInt->new(10)->bpow($bg_decimals));
            } else {
                $transaction_cp->{amount} = $amount;
            }

            if (@topics > 1) {
                $transaction_cp->{to} = $self->_remove_zeros($topics[2]);
            }

            $transaction_cp->{contract} = $address;

            push(@transactions, $transaction_cp);
        }
    }

    return @transactions;
}

=head2 _check_internal_transaction

For now this method just check the internal transactions

Returns an array of hashrefs with fields matching attributes in L<Net::Async::Blockchain::Transaction>

=cut

async sub _check_internal_transaction {
    my ($self, $transaction) = @_;

    my %transactions;
    my $internal_transactions = await $self->tp_api->get_internal_transactions($transaction->{hash});
    return () unless $internal_transactions;
    for my $internal ($internal_transactions->@*) {
        next if $internal->{value} == 0 || $internal->{type} ne 'call' || $internal->{isError};
        my $transaction_cp = $transaction->clone();
        $transaction_cp->{amount}    = Math::BigFloat->new($internal->{value})->bdiv(10**DEFAULT_DECIMAL_PLACES)->bround(DEFAULT_DECIMAL_PLACES);
        $transaction_cp->{to}        = $internal->{to};
        $transaction_cp->{from}      = $internal->{from};
        $transaction_cp->{block}     = $internal->{blockNumber};
        $transaction_cp->{timestamp} = $internal->{timeStamp};
        $transaction_cp->{contract}  = $internal->{contractAddress};
        $transaction_cp->{data}      = $internal->{input};
        
        if($transactions{$internal->{to}})
        {
            $transactions{$internal->{to}}->{amount}->badd($transaction_cp->{amount});
        } else {
            $transactions{$internal->{to}} = $transaction_cp;
        }

    }

    return values %transactions;
}

=head2 _remove_zeros

The address on the topic logs is always a 32 bytes string so we will
have addresses like: `000000000000000000000000c636d4c672b3d3760b2e759b8ad72546e3156ce9`

We need to remove all the extra zeros and add the `0x`

=over 4

=item * C<trxn_topic> The log string

=back

string

=cut

sub _remove_zeros {
    my ($self, $trxn_topic) = @_;

    # get only the last 40 characters from the string (ETH address size).
    my $address = substr($trxn_topic, -40, length($trxn_topic));

    return "0x$address";
}

=head2 _to_string

The response from the contract will be in the dynamic type format when we call the symbol, so we will
have a response like: `0x00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000003414c480000000000000000000000000000000000000000000000000000000000`

This is basically:

First 32 bytes: 0000000000000000000000000000000000000000000000000000000000000020 = 32 (offset to start of data part of second parameter)
Second 32 bytes: 0000000000000000000000000000000000000000000000000000000000000003 = 3 (value size)
Third 32 bytes: 414c480000000000000000000000000000000000000000000000000000000000 = ALH (padded left value)

=over 4

=item * C<trxn_topic> The log string

=back

string

=cut

sub _to_string {
    my ($self, $response) = @_;

    return undef unless $response;

    $response = substr($response, 2) if $response =~ /^0x/;

    # split every 32 bytes
    my @chunks = $response =~ /(.{1,64})/g;

    return undef unless scalar @chunks >= 3;

    # position starting from the second item
    my $position = Math::BigFloat->from_hex($chunks[0])->bdiv(32)->badd(1)->bint();

    # size
    my $size = Math::BigFloat->from_hex($chunks[1])->bint();

    # hex string to string
    my $packed_response = pack('H*', $chunks[$position]);

    # substring by the data size
    return substr($packed_response, 0, $size);
}

=head2 get_numeric_from_hex

Check if the given hexadecimal is numeric and returns the based big number

=over 4

=item * C<hex> hexadecimal response from the blockchain client

=back

Returns a L<Math::BigFloat> value based on the given hexadecimal if it is numeric
not numeric will return undef

=cut

sub get_numeric_from_hex {
    my ($self, $hex) = @_;

    my $check_string = $self->_to_string($hex);
    return undef if $check_string;

    # numeric responses should have at least 64 characters
    # 66 including 0x
    # transaction data field / contract response
    return undef unless ($hex && length($hex) == 66);

    return Math::BigFloat->from_hex($hex);
}

1;
