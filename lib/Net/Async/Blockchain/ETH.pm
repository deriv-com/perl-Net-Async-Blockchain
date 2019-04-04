package Net::Async::Blockchain::ETH;

use strict;
use warnings;
no indirect;

use Future::AsyncAwait;
use Ryu::Async;
use JSON::MaybeUTF8 qw(decode_json_utf8 encode_json_utf8);
use JSON;
use Math::BigFloat;
use Digest::Keccak qw(keccak_256_hex);

use Net::Async::Blockchain::Client::RPC;
use Net::Async::Blockchain::Subscription::Websocket;

use base qw(Net::Async::Blockchain);

use constant {
    TRANSFER_SIGNATURE => keccak_256_hex('Transfer(address,address,uint256)'),
    SYMBOL_SIGNATURE => keccak_256_hex('symbol()'),
};

sub currency_code { 'ETH' }

sub subscription_id { shift->{subscription_id} }

sub new_websocket_client {
    my ($self) = @_;
    $self->add_child(my $ws_source = Ryu::Async->new());
    $self->add_child(my $client = Net::Async::Blockchain::Subscription::Websocket->new(
        endpoint => $self->config->{subscription_url},
        source => $ws_source->source,
    ));
    return $client;
}

sub subscribe {
    my ($self, $subscription) = @_;

    die "Invalid or not implemented subscription" unless $subscription && $self->can($subscription);

    $self->new_websocket_client()->eth_subscribe($subscription)
        # the first response from the node is the subscription id
        # once we received it we can start to listening the subscription.
        ->skip_until(sub{
                my $response = shift;
                return 1 unless $response->{result};
                $self->{subscription_id} = $response->{result};
                return 0;
            })
        # we use the subscription id received as the first response to filter
        # all incoming subscription responses.
        ->filter(sub {
                my $response = shift;
                return undef unless $response->{params} && $response->{params}->{subscription};
                return $response->{params}->{subscription} eq $self->subscription_id;
            })
        ->each(async sub{ await $self->$subscription(shift) });

    return $self->source;
}

async sub newHeads {
    my ($self, $response) = @_;

    my $block = $response->{params}->{result};

    my $block_response = await $self->rpc_client->eth_getBlockByHash($block->{hash}, JSON->true);
    my @transactions = $block_response->{transactions}->@*;
    await Future->needs_all(map {$self->transform_transaction($_)} @transactions);
}

async sub transform_transaction {
    my ($self, $decoded_transaction) = @_;

    # Contract creation transactions.
    return undef unless $decoded_transaction->{to};

    # fee = gas * gasPrice
    my $fee = Math::BigFloat->from_hex($decoded_transaction->{gas})->bmul($decoded_transaction->{gasPrice});
    my $amount = Math::BigFloat->from_hex($decoded_transaction->{value});

    my $transaction = Net::Async::Blockchain::Transaction->new(
        currency => $self->currency_code,
        hash => $decoded_transaction->{hash},
        from => $decoded_transaction->{from},
        to => $decoded_transaction->{to},
        contract => '',
        amount => $amount,
        fee => $fee,
        fee_currency => $self->currency_code,
        type => '',
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

    if($transactions){
        $self->source->emit($_) for $transactions->@*;
    }

    return 1;
}


async sub _set_transaction_type {
    my ($self, $transactions) = @_;

    return undef unless $transactions;

    my $accounts_response = await $self->rpc_client->eth_accounts();
    return undef unless $accounts_response;

    my %accounts = map {$_ => 1} $accounts_response->@*;

    my @node_transactions;
    for my $transaction ($transactions->@*) {
        my $from = $accounts{$transaction->from};
        my $to = $accounts{$transaction->to};

        if ($from && $to) {
            $transaction->type('internal');
        } elsif ($from) {
            $transaction->type('sent');
        } elsif ($to) {
            $transaction->type('receive');
        } else {
            next;
        }
        push (@node_transactions, $transaction) if $transaction->type;
    }


    return \@node_transactions;
}

async sub _check_contract_transaction {
    my ($self, $transaction) = @_;

    my @transactions;

    my $receipt = await $self->rpc_client->eth_getTransactionReceipt($transaction->hash);
    my $logs = $receipt->{logs};

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

            my $hex_symbol = await $self->rpc_client->eth_call([{data => SYMBOL_SIGNATURE, to => $log->{address}}, "latest"]);
            my $symbol = $self->_to_string($hex_symbol);
            next unless $symbol;

            $transaction_cp->currency($symbol);
            $transaction_cp->contract($log->{address});

            my @topics = $log->{topics}->@*;
            # the topics for the transfer transaction are:
            # - method signature
            # - sender address
            # - to address
            # - tokens
            if($topics[2]) {
                $transaction_cp->to($self->_remove_zeros($topics[2]));
                $transaction_cp->amount(Math::BigFloat->from_hex($log->{data}));
                push(@transactions, $transaction_cp);
            }
        }

    } else {
        push(@transactions, $transaction);
    }

    return \@transactions;
}

sub _remove_zeros {
    my ($self, $trxn_topic) = @_;

    # remove 0x
    my $address = substr($trxn_topic, 2);
    # remove all left 0
    $address =~ s/^0+(?=.)//s;
    return "0x$address";
}

sub _to_string {
    my ($self, $response) = @_;

    return undef unless $response;

    my $packed_response = pack('H*', substr($response, -64));
    $packed_response =~ s/\0+$//;

    return $packed_response;
}

1;

