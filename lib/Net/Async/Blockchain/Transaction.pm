package Net::Async::Blockchain::Transaction;

use strict;
use warnings;

our $VERSION = '0.001';

=head1 NAME

Net::Async::Blockchain::Transaction - Transaction abstraction.

=head1 SYNOPSIS

Objects of this type would not normally be constructed directly.

This object will the return from the subscriptions

=head1 DESCRIPTION

Transaction abstraction

=over 4

=back

=cut

no indirect;

=head2 currency

Currency symbol

=over 4

=back

String currency symbol

=cut

sub currency : method { shift->{currency} }

=head2 hash

Transaction hash

=over 4

=back

String transaction hash

=cut

sub hash : method { shift->{hash} }

=head2 block

Block where the transaction is included

=over 4

=back

Integer block number

=cut

sub block : method { shift->{block} }

=head2 from

Transaction sender

=over 4

=back

String blockchain address

=cut

sub from : method { shift->{from} }

=head2 to

Transaction receiver

=over 4

=back

String blockchain address

=cut

sub to : method { shift->{to} }

=head2 contract

Contract address (when it's a contract transaction)

=over 4

=back

Can return undef or the contract address

=cut

sub contract : method { shift->{contract} }

=head2 amount

The transaction value

=over 4

=back

Float amount

=cut

sub amount : method { shift->{amount} }

=head2 fee

The fee paid for this transaction

=over 4

=back

Float fee

=cut

sub fee : method { shift->{fee} }

=head2 fee_currency

The currency of the fee paid for this transaction

=over 4

=back

String currency symbol

=cut

sub fee_currency : method { shift->{fee_currency} }

=head2 type

Transaction type

=over 4

=back

String transaction type it can be (receive, sent, internal)

=cut

sub type : method { shift->{type} }

=head2 new

Create a new L<Net::Async::Blockchain::Transaction> instance

=over 4

=back

L<Net::Async::Blockchain::Transaction>

=cut

sub new {
    my ($class, %params) = @_;

    my $self = bless {}, $class;

    foreach (qw(currency hash block from to contract amount fee fee_currency type)) {
        $self->{$_} = delete $params{$_} if exists $params{$_};
    }

    die "Invalid transaction parameters" if keys %params;
    return $self;
}

=head2 clone

Clone the self object and the attribute values

=over 4

=back

new L<Net::Async::Blockchain::Transaction> based on self

=cut

sub clone {
    my ($self) = @_;
    my $clone = Net::Async::Blockchain::Transaction->new();
    @{$clone}{keys %$self} = values %$self;
    return $clone;
}

1;
