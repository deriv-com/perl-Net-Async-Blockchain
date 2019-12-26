package Net::Async::Blockchain::Plugins::ETH::ERC20;

use strict;
use warnings;
no indirect;

use Digest::Keccak qw(keccak_256_hex);
use Future::AsyncAwait;

our $VERSION = '0.001';

use parent qw(Net::Async::Blockchain::Plugins::ETH::Utility);

use constant {
    TRANSFER_EVENT_SIGNATURE => '0x' . keccak_256_hex('Transfer(address,address,uint256)'),
    SYMBOL_SIGNATURE         => '0x' . keccak_256_hex('symbol()'),
    DECIMALS_SIGNATURE       => '0x' . keccak_256_hex('decimals()'),
};

=head2 enabled

To disable this plugin set the return to 0

=cut

sub enabled { return 1 }

=head2 check

Check if the transactions contains ERC20 transfers

=over 4

=item * client L<Net::Async::Blockchain::ETH>

=item * L<Net::Async::Blockchain::Transaction>

=item * transaction receipt received from `eth_getTransactionReceipt`

=back

hashref from an array of L<Net::Async::Blockchain::Transaction>

=cut

async sub check {
    my ($self, $client, $transaction, $receipt) = @_;
    my $logs = $receipt->{logs};
    my @transactions;

    if (ref $logs eq 'ARRAY' && scalar $logs->@* > 0) {
        return undef unless $receipt->{status} && hex($receipt->{status}) == 1;

        for my $log ($logs->@*) {
            my @topics = $log->{topics}->@*;
            if (@topics && $topics[0] eq TRANSFER_EVENT_SIGNATURE) {
                my $transaction_cp = $transaction->clone();

                my $address = $log->{address};
                my $amount  = Math::BigFloat->from_hex($log->{data});

                my $hex_symbol = await $client->rpc_client->call({
                        data => SYMBOL_SIGNATURE,
                        to   => $address
                    },
                    "latest"
                );

                my $symbol = $self->_to_string($hex_symbol);
                next unless $symbol;

                $transaction_cp->{currency} = $symbol;

                my $decimals = await $client->rpc_client->call({
                        data => DECIMALS_SIGNATURE,
                        to   => $address
                    },
                    "latest"
                );

                if ($decimals) {
                    # default size 64 + `0x`
                    next unless length($decimals) == 66;
                    $transaction_cp->{amount} = $amount->bdiv(Math::BigInt->new(10)->bpow($decimals));
                } else {
                    $transaction_cp->{amount} = $amount;
                }

                if (scalar @topics > 1) {
                    $transaction_cp->{to} = $self->_remove_zeros($topics[2]);
                }

                $transaction_cp->{contract} = $address;

                push(@transactions, $transaction_cp);
            }
        }
    }

    return @transactions;
}

1;
