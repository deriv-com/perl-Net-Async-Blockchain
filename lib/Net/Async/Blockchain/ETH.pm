package Net::Async::Blockchain::ETH;

use strict;
use warnings;
no indirect;

use Future::AsyncAwait;
use Ryu::Async;
use JSON::MaybeUTF8 qw(decode_json_utf8 encode_json_utf8);
use JSON;
use Math::BigFloat;
use Net::Async::WebSocket::Client;

use Net::Async::Blockchain::Subscription::Websocket;

use base qw(Net::Async::Blockchain);

use constant {
    # Transfer(address,address,uint256)
    TRANSFER_SIGNATURE => '0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef',
    # symbol()
    SYMBOL_SIGNATURE => '0xbe16b05c387bab9ac31918a3e61672f4618601f3c598a2f3f2710f37053e1ea4',
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
        ->skip_until(sub{
                my $response = shift;
                return 1 unless $response->{result};
                $self->{subscription_id} = $response->{result};
                return 0;
            })
        ->filter(sub {
                my $response = shift;
                return undef unless $response->{params} && $response->{params}->{subscription};
                return $response->{params}->{subscription} eq $self->subscription_id;
            })
        ->each(sub{$self->$subscription(shift)});

    return $self->source;
}

sub newHeads {
    my ($self, $response) = @_;

    die "Invalid node response for newHeads subscription" unless $response->{params} && $response->{params}->{result};
    my $block = $response->{params}->{result};

    $self->new_websocket_client()->eth_getBlockByHash($block->{hash}, JSON->true)
        ->take(1)
        ->each(sub{
                my ($block_response) = @_;

                my @transactions = $block_response->{result}->{transactions}->@*;
                my @futures = map {$self->transform_transaction($_)} @transactions;
                Future->needs_all(@futures);
            });
}

async sub transform_transaction {
    my ($self, $decoded_transaction) = @_;

    # Contract creation transactions.
    return undef unless $decoded_transaction->{to};

    my $fee = Math::BigFloat->from_hex($decoded_transaction->{gas})->bmul($decoded_transaction->{gasPrice});
    my $amount = Math::BigFloat->from_hex($decoded_transaction->{value});

    my $transaction = {
        currency => $self->currency_code,
        hash => $decoded_transaction->{hash},
        from => $decoded_transaction->{from},
        to => $decoded_transaction->{to},
        contract => '',
        amount => $amount,
        fee => $fee,
        fee_currency => $self->currency_code,
        type => '',
    };

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

    my @accounts_response = await $self->new_websocket_client->eth_accounts()->take(1)->as_list;
    return undef unless $accounts_response[0] and $accounts_response[0]->{result};

    my %accounts = map {$_ => 1} $accounts_response[0]->{result}->@*;

    my @node_transactions;
    for my $transaction ($transactions->@*) {
        my $from = $accounts{$transaction->{from}};
        my $to = $accounts{$transaction->{to}};

        if ($from && $to) {
            $transaction->{type} = 'internal';
        } elsif ($from) {
            $transaction->{type} = 'sent';
        } elsif ($to) {
            $transaction->{type} = 'received';
        } else {
            next;
        }
        push (@node_transactions, $transaction) if $transaction->{type};
    }


    return \@node_transactions;
}

async sub _check_contract_transaction {
    my ($self, $transaction) = @_;

    my @transactions;

    my @receipts =
        await $self->new_websocket_client->eth_getTransactionReceipt($transaction->{hash})
            ->take(1)
            ->as_list;

    my $receipt = $receipts[0];
    my $logs = $receipt->{result}->{logs};

    # Contract
    if ($logs->@* > 0) {
        # Ignore unsuccessful transactions.
        return undef unless $receipt->{result}->{status} && hex($receipt->{result}->{status}) == 1;

        # The first topic is the hash of the signature of the event.
        my @transfer_logs = grep { $_->{topics} && $_->{topics}[0] eq TRANSFER_SIGNATURE } @$logs;

        # Only Transfer support for now.
        return undef unless @transfer_logs;

        for my $log (@transfer_logs) {
            my $transaction_cp = {};
            @{$transaction_cp}{keys %$transaction} = values %$transaction;

            my @currency_code = await $self->new_websocket_client->eth_call([{data => SYMBOL_SIGNATURE, to => $log->{address}}, "latest"])->take(1)->as_list;
            my $currency_code_str = $self->_to_string($currency_code[0]->{result});

            $transaction_cp->{currency} = $currency_code_str;
            $transaction_cp->{contract} = $log->{address};

            my @topics = $log->{topics}->@*;
            if($topics[2]) {
                $transaction_cp->{to} = $self->_remove_zeros($topics[2]);
                $transaction_cp->{contract_amount} = Math::BigFloat->from_hex($log->{data});
                push(@transactions, $transaction_cp);
                last;
            } else {
                return undef;
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

