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

    $omni_client->subscribe("transactions")->each(sub { print shift->{hash} })->get;

=head1 DESCRIPTION

Omnicore subscription using ZMQ from the bitcoin based blockchain nodes

=over 4

=back

=cut

no indirect;

use Ryu::Async;
use Future;
use Future::AsyncAwait;
use IO::Async::Loop;
use Math::BigFloat;
use Syntax::Keyword::Try;

use Net::Async::Blockchain::Transaction;
use Net::Async::Blockchain::Client::RPC::Omni;

use parent qw(Net::Async::Blockchain::BTC);

# fee for Omnicore is always BTC
use constant FEE_CURRENCY => 'BTC';

my %subscription_dictionary = ('transactions' => 'hashblock');

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
        $self->add_child(my $http_client = Net::Async::Blockchain::Client::RPC::Omni->new(endpoint => $self->rpc_url));
        $http_client;
    };
}

=head2 hashblock

hashblock subscription

Convert and emit a L<Net::Async::Blockchain::Transaction> for the client source every new block received that
is owned by the node.

=over 4

=item * C<block_hash> omnicore block hash

=back

=cut

async sub hashblock {
    my ($self, $block_hash) = @_;

    my $block_response = await $self->rpc_client->get_block($block_hash);

    # 2 here for full verbosity
    my @future_transactions = map { $self->rpc_client->get_raw_transaction($_, 2) } $block_response->{tx}->@*;
    await Future->needs_all(@future_transactions);

    my @transactions = map { $_->get } @future_transactions;

    await Future->needs_all(map { $self->transform_transaction($_) } @transactions);
}

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
    my $received_transaction;
    try {
        $received_transaction = await $self->rpc_client->get_transaction($decoded_raw_transaction->{txid});
    }
    catch {
        # transaction not found
        return undef;
    }

    # transaction not found, just ignore.
    return undef unless $received_transaction && $received_transaction->{ismine};

    my $amount = Math::BigFloat->new($received_transaction->{amount});
    my $fee = Math::BigFloat->new($received_transaction->{fee} // 0);

    my ($from, $to) =
        await Future->needs_all(map { $self->rpc_client->validate_address($received_transaction->{$_}) } qw(sendingaddress referenceaddress));

    # it can be receive, sent, internal
    # if categories has send and receive it means that is an internal transaction
    my $transaction_type;
    if ($from->{ismine} && $to->{ismine}) {
        $transaction_type = 'internal';
    } elsif ($from->{ismine}) {
        $transaction_type = 'sent';
    } elsif ($to->{ismine}) {
        $transaction_type = 'receive';
    }

    return undef unless $transaction_type;

    my $transaction = Net::Async::Blockchain::Transaction->new(
        currency     => $self->currency_symbol,
        hash         => $decoded_raw_transaction->{txid},
        block        => $received_transaction->{block},
        from         => $from->{address},
        to           => [$to->{address}],
        amount       => $amount,
        fee          => $fee,
        fee_currency => FEE_CURRENCY,
        type         => $transaction_type,
        property_id  => $received_transaction->{propertyid},
    );

    $self->source->emit($transaction) if $transaction;

    return 1;
}

1;
