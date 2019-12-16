package Net::Async::Blockchain::Plugins::ETH::ERC20;

use strict;
use warnings;
no indirect;

use Digest::Keccak qw(keccak_256_hex);
use Future::AsyncAwait;

our $VERSION = '0.001';

use parent qw(Net::Async::Blockchain::Plugins::ETH::Utility);

use constant {
    TRANSFER_EVENT_SIGNATURE     => '0x' . keccak_256_hex('Transfer(address,address,uint256)'),
    SYMBOL_SIGNATURE       => '0x' . keccak_256_hex('symbol()'),
    DECIMALS_SIGNATURE     => '0x' . keccak_256_hex('decimals()'),
};

sub enabled { return 1 }

=head2 check

We need to identify what are the transactions that have a contract as
destination, once we found we change:

currency => the contract symbol
amount => tokens
to => address that will receive the tokens
contract => the contract address

=over 4

=item * L<Net::Async::Blockchain::Transaction>

=back

hashref from an array of L<Net::Async::Blockchain::Transaction>

=cut

async sub check {
    my ($self, $transaction, $receipt) = @_;

    my $logs = $receipt->{logs};
    my @transactions;

    if (scalar $logs->@* > 0) {
        return undef unless $receipt->{status} && hex($receipt->{status}) == 1;

        for my $log ($logs->@*) {
            my @topics = $log->{topics}->@*;
            if (@topics && $topics[0] eq TRANSFER_EVENT_SIGNATURE) {
                my $transaction_cp = $transaction->clone();

                my $address = $log->{address};
                my $amount = Math::BigFloat->from_hex($log->{data});

                my $hex_symbol = await $self->rpc_client->call({
                        data => SYMBOL_SIGNATURE,
                        to   => $address
                    },
                    "latest"
                );

                my $symbol = $self->_to_string($hex_symbol);
                return undef unless $symbol;

                $transaction->{currency} = $symbol;

                my $decimals = await $self->rpc_client->call({
                        data => DECIMALS_SIGNATURE,
                        to   => $address
                    },
                    "latest"
                );

                if ($decimals) {
                    $transaction->{amount} = $amount->bdiv(Math::BigInt->new(10)->bpow($decimals))->bround(hex $decimals);
                }else{
                    $transaction->{amount} = $amount;
                }

                if (scalar @topics > 1) {
                    $transaction_cp->{to} = [$self->_remove_zeros($topics[2])];
                }

                $transaction->{contract} = $address;

                push(@transactions, $transaction);
            }
        }
    }
}

1;

