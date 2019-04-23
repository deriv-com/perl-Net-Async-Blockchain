package Net::Async::Blockchain::Omni;

use strict;
use warnings;

our $VERSION = '0.001';

=head1 NAME

Net::Async::Blockchain::Omni - Omnicore based subscription.

=head1 SYNOPSIS

    my $loop = IO::Async::Loop->new;

    $loop->add(
        my $omni_client = Net::Async::Blockchain::Omni->new(
            subscription_url => "tcp://127.0.0.1:28332",
            rpc_url => 'http://test:test@127.0.0.1:8332',
            rpc_timeout => 100,
        )
    );

    $omni_client->subscribe("transactions")->each(sub { print shift->{hash} });

    $loop->run();


=head1 DESCRIPTION

Omnicore subscription using ZMQ from the bitcoin based blockchain nodes

=over 4

=back

=cut

no indirect;

use Ryu::Async;
use Future::AsyncAwait;
use IO::Async::Loop;
use Math::BigFloat;

use Net::Async::Blockchain::Transaction;

use parent qw(Net::Async::Blockchain::BTC);

# fee for Omnicore is always BTC
use constant FEE_CURRENCY => 'BTC';

my %subscription_dictionary = ('transactions' => 'hashblock');

=head2 transform_transaction

Receive a decoded raw transaction and convert it to a L<Net::Async::Blockchain::Transaction> object

=over 4

=item * C<decoded_raw_transaction> the response from the command `decoderawtransaction`

=back

L<Net::Async::Blockchain::Transaction>

=cut

async sub transform_transaction {
    my ($self, $decoded_raw_transaction) = @_;

    # the command listtransactions will guarantee that this transactions is from or to one
    # of the node addresses.
    my $received_transaction = await $self->rpc_client->omni_gettransaction($decoded_raw_transaction->{txid});

    # transaction not found, just ignore.
    return undef unless $received_transaction && $received_transaction->{is_mine};

    my $amount = Math::BigFloat->new($received_transaction->{amount});
    my $fee = Math::BigFloat->new($received_transaction->{fee} // 0);

    my $from = $self->rpc_client->validateaddress($received_transaction->{sendingaddress});
    my $to   = $self->rpc_client->validateaddress($received_transaction->{referenceaddress});

    # it can be receive, sent, internal
    # if categories has send and receive it means that is an internal transaction
    my $transaction_type;
    if ($from->{is_mine} && $to->{is_mine}) {
        $transaction_type = 'internal';
    } elsif ($from->{is_mine}) {
        $transaction_type = 'sent';
    } elsif ($to->{is_mine}) {
        $transaction_type = 'receive';
    }

    return undef unless $transaction_type;

    my $transaction = Net::Async::Blockchain::Transaction->new(
        currency     => $self->currency_symbol,
        hash         => $decoded_raw_transaction->{txid},
        block        => $decoded_raw_transaction->{block},
        from         => $from->{address},
        to           => [$to->{address}],
        amount       => $amount,
        fee          => $fee,
        fee_currency => FEE_CURRENCY,
        type         => $transaction_type,
    );

    $self->source->emit($transaction) if $transaction;

    return 1;
}

1;
