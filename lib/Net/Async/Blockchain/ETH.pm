package Net::Async::Blockchain::ETH;

use strict;
use warnings;
no indirect;

use Future::AsyncAwait;
use Ryu::Async;
use JSON::MaybeUTF8 qw(decode_json_utf8 encode_json_utf8);
use JSON;

use Net::Async::Blockchain::Subscription::Websocket;

use base qw(Net::Async::Blockchain);

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

    $self->new_websocket_client()->eth_subscribe(1, $subscription)
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

    $self->new_websocket_client()->eth_getBlockByHash(2, $block->{hash}, JSON->true)
        ->filter(id => 2)
        ->take(1)
        ->each(async sub{
                my ($block_response) = @_;
                my @transactions = $block_response->{result}->{transactions}->@*;
                for my $transaction (@transactions) {
                    my $default_transaction = await $self->transform_transaction($transaction);
                    $self->source->emit($default_transaction) if $default_transaction;
                }
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
        amount => $amount,
        contract_amount => Math::BigFloat->bzero(),
        contract_currency => undef,
        fee => $fee,
        fee_currency => $self->currency_code,
        type => '',
    };

    # my @receipts =
    #     await $self->new_websocket_client->eth_getTransactionReceipt(2, $decoded_transaction->{hash})
    #         ->filter(id => 2)
    #         ->take(1)
    #         ->as_list;

    # my $receipt = $receipts[0];
    # my $logs = $receipt->{result}->{logs};

    # # Contract
    # if ($logs->@* > 0) {
    #     # Ignore unsuccessful transactions.
    #     return undef unless $receipt->{result}->{status} && hex($receipt->{result}->{status}) == 1;

    #     # ERC20 transfer event.
    #     my $event = await $self->_get_event_signature('Transfer(address,address,uint256)');

    #     # The first topic is the hash of the signature of the event.
    #     my @transfer_logs = grep { $_->{topics} and $_->{topics}[0] eq $event } @$logs;

    #     # Only ERC20 support for now.
    #     return undef unless @transfer_logs;

    #     my $log = $transfer_log[0];

    #     for my $log (@transfer_logs) {
    #         my @topics = $log->{topics};
    #         push $transaction->{to}, $log->_remove_zeros($topics[2]);
    #         $transaction->{contract_amount}->badd(Math::BigFloat->from_hex($log->{data}));
    #     }

    # }

    return $transaction;
}

# async sub _get_event_signature {
#     my ($self, $method) = @_;

#     my $hex = sprintf("0x%s", unpack("H*", $method));

#     my @sha3_hex = await $self->new_websocket_client->web3_sha3(2, $hex)->take(1)->as_list;

#     return $sha3_hex[0]->{result};
# }

# sub _remove_zeros {
#     my ($self, $trxn_topic) = @_;

#     # remove 0x
#     my $address = substr($trxn_topic, 2);
#     # remove all left 0
#     $address =~ s/^0+(?=.)//s;
#     return "0x$address";
# }


1;

