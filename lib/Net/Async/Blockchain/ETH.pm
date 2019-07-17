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
use JSON::MaybeXS;
use Math::BigInt;
use Math::BigFloat;
use Digest::Keccak qw(keccak_256_hex);
use List::Util qw(any);

use Net::Async::Blockchain::Transaction;
use Net::Async::Blockchain::Client::RPC::ETH;
use Net::Async::Blockchain::Client::Websocket;

use parent qw(Net::Async::Blockchain);

use constant {
    TRANSFER_SIGNATURE => '0x' . keccak_256_hex('Transfer(address,address,uint256)'),
    SYMBOL_SIGNATURE   => '0x' . keccak_256_hex('symbol()'),
    DEFAULT_CURRENCY   => 'ETH',
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
        $self->add_child(my $http_client = Net::Async::Blockchain::Client::RPC::ETH->new(endpoint => $self->rpc_url));
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
            endpoint => $self->subscription_url,
        ));
    return $client;
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
        })->ordered_futures;

    return $self->source;
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

    my $block_response = await $self->rpc_client->get_block_by_hash($block->{hash}, JSON::MaybeXS->true);
    my @transactions = $block_response->{transactions}->@*;
    await Future->needs_all(map { $self->transform_transaction($_) } @transactions);

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
    my ($self, $decoded_transaction) = @_;

    # Contract creation transactions.
    return undef unless $decoded_transaction->{to};

    # fee = gas * gasPrice
    my $fee    = Math::BigFloat->from_hex($decoded_transaction->{gas})->bmul($decoded_transaction->{gasPrice});
    my $amount = Math::BigFloat->from_hex($decoded_transaction->{value});
    my $block  = Math::BigInt->from_hex($decoded_transaction->{blockNumber});

    my $transaction = Net::Async::Blockchain::Transaction->new(
        currency     => $self->currency_symbol,
        hash         => $decoded_transaction->{hash},
        block        => $block,
        from         => $decoded_transaction->{from},
        to           => [$decoded_transaction->{to}],
        contract     => '',
        amount       => $amount,
        fee          => $fee,
        fee_currency => $self->currency_symbol,
        type         => '',
    );

    # check if the transaction is from an ERC20 contract
    # this can return more than one transaction since we can have
    # logs for different contracts in the same transaction.
    my $transactions = await $self->_check_contract_transaction($transaction);

    # set the type for each transaction
    # from and to => internal
    # to => received
    # from => sent
    $transactions = await $self->_set_transaction_type($transactions) if $transactions;

    if ($transactions) {
        $self->source->emit($_) for $transactions->@*;
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
    my ($self, $transactions) = @_;

    return undef unless $transactions;

    my $accounts_response = await $self->rpc_client->accounts();
    return undef unless $accounts_response;

    my %accounts = map { $_ => 1 } $accounts_response->@*;

    my @node_transactions;
    for my $transaction ($transactions->@*) {
        my $from = $accounts{$transaction->from};
        my $to = any { $accounts{$_} } $transaction->to->@*;

        if ($from && $to) {
            $transaction->{type} = 'internal';
        } elsif ($from) {
            $transaction->{type} = 'sent';
        } elsif ($to) {
            $transaction->{type} = 'receive';
        } else {
            next;
        }
        push(@node_transactions, $transaction) if $transaction->type;
    }

    return \@node_transactions;
}

=head2 _check_contract_transaction

We need to identify what are the transactions that have a contract as
destination, once we found we change:

currency => the contract symbol
amount => tokens
to => address that will receive the tokens
contract => the contract address

One contract transaction can have multiple contract transfer so here we can
return one or more transactions.

=over 4

=item * L<Net::Async::Blockchain::Transaction>

=back

hashref from an array of L<Net::Async::Blockchain::Transaction>

=cut

async sub _check_contract_transaction {
    my ($self, $transaction) = @_;

    my @transactions;

    my $receipt = await $self->rpc_client->get_transaction_receipt($transaction->hash);
    my $logs    = $receipt->{logs};

    # Contract
    if ($logs->@* > 0) {
        # Ignore unsuccessful transactions.
        return undef unless $receipt->{status} && hex($receipt->{status}) == 1;

        # The first topic is the hash of the signature of the event.
        my @transfer_logs = grep { $_->{topics} && $_->{topics}[0] eq TRANSFER_SIGNATURE } @$logs;

        # Only Transfer support for now.
        return undef unless @transfer_logs;

        for my $log (@transfer_logs) {
            my $transaction_cp = $transaction->clone();

            my $hex_symbol = await $self->rpc_client->call({
                    data => SYMBOL_SIGNATURE,
                    to   => $log->{address}
                },
                "latest"
            );
            my $symbol = $self->_to_string($hex_symbol);
            next unless $symbol;

            $transaction_cp->{currency} = $symbol;
            $transaction_cp->{contract} = $log->{address};

            my @topics = $log->{topics}->@*;

            # the third item of the transfer log array is always the `to` address
            if ($topics[2]) {
                $transaction_cp->{to}     = [$self->_remove_zeros($topics[2])];
                $transaction_cp->{amount} = Math::BigFloat->from_hex($log->{data});
                push(@transactions, $transaction_cp);
            }
        }

    } else {
        push(@transactions, $transaction);
    }

    return \@transactions;
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

    # remove 0x
    my $address = substr($trxn_topic, 2);
    # remove all left 0
    $address =~ s/^0+(?=.)//s;
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

1;

