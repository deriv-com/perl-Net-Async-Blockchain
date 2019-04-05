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

=cut

no indirect;

sub currency : method { shift->{currency} }
sub hash : method { shift->{hash} }
sub block : method { shift->{block} }
sub from : method { shift->{from} }
sub to : method { shift->{to} }
sub contract : method { shift->{contract} }
sub amount : method { shift->{amount} }
sub fee : method { shift->{fee} }
sub fee_currency : method { shift->{fee_currency} }
sub type : method { shift->{type} }

sub new {
   my $class = shift;
   my %params = @_;

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
