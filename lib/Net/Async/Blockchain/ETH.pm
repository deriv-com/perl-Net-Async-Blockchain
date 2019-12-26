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
use List::Util qw(any);
use Syntax::Keyword::Try;
use Module::PluginFinder;

use Net::Async::Blockchain::Transaction;
use Net::Async::Blockchain::Client::RPC::ETH;
use Net::Async::Blockchain::Client::Websocket;

use parent qw(Net::Async::Blockchain);

use constant {
    DEFAULT_CURRENCY       => 'ETH',
    DEFAULT_DECIMAL_PLACES => 18,
    UPDATE_ACCOUNTS        => 10,
};

my %subscription_dictionary = ('transactions' => 'newHeads');

my $filter = Module::PluginFinder->new(
    search_path => 'Net::Async::Blockchain::Plugins::ETH',
    filter      => sub { },
);

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

async sub accounts {
    my $self = shift;
    return $self->{accounts} //= do {
        $self->get_hash_accounts();
    };
}

=head2 update_accounts

update the C<accounts> variable every 10 seconds

=over 4

=back

=cut

async sub update_accounts {
    my $self = shift;
    while (1) {
        $self->{accounts} = $self->get_hash_accounts();
        await $self->loop->delay_future(after => UPDATE_ACCOUNTS);
    }
}

=head2 get_hash_accounts

Request the node accounts and convert it to a hash

=back

hash ref containing the accounts as keys

=cut

async sub get_hash_accounts {
    my ($self) = @_;

    my @accounts_response = await $self->rpc_client->accounts();
    my %accounts = map { lc($_) => 1 } @accounts_response;
    return \%accounts;
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
        $self->update_accounts(),
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

    unless ($current_block->bgt(0)) {
        my $syncing = await $self->rpc_client->syncing();
        $current_block = Math::BigInt->from_hex($syncing->{currentBlock}) if $syncing;
    }

    return undef unless $current_block;

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
        my $gas     = $decoded_transaction->{gas};
        my $receipt = await $self->rpc_client->get_transaction_receipt($decoded_transaction->{hash});

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

        my @transactions = await $self->_check_plugins($transaction, $receipt);

        unless (scalar @transactions) {
            @transactions = ($transaction);
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

    my $accounts = await $self->accounts;
    return undef unless $accounts;

    my %accounts = $accounts->%*;

    my $from = $accounts{lc($transaction->from)};
    my $to   = $accounts{lc($transaction->to)};

    if ($from && $to) {
        $transaction->{type} = 'internal';
    } elsif ($from) {
        $transaction->{type} = 'sent';
    } elsif ($to) {
        $transaction->{type} = 'receive';
    }

    return $transaction->type ? $transaction : undef;
}

=head2 _check_plugins

=over 4

=item * L<Net::Async::Blockchain::Transaction>

=back

hashref from an array of L<Net::Async::Blockchain::Transaction>

=cut

async sub _check_plugins {
    my ($self, $transaction, $receipt) = @_;

    my @modules = $filter->modules();
    my @transactions;

    for my $module (grep { $_->can("enabled") && $_->enabled } @modules) {
        my @module_response = await $module->check($self, $transaction, $receipt);
        push(@transactions, @module_response) if @module_response;
        undef @module_response;
    }

    undef @modules;

    return @transactions;
}

1;
