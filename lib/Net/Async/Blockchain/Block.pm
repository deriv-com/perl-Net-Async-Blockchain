package Net::Async::Blockchain::Block;

use strict;
use warnings;

our $VERSION = '0.001';

=head1 NAME

Net::Async::Blockchain::Block - Block abstraction.

=head1 SYNOPSIS

Objects of this type would not normally be constructed directly.

=head1 DESCRIPTION

Block abstraction

=over 4

=back

=cut

no indirect;

sub message_type : method { 'block' }
sub currency : method     { shift->{currency} }
sub number : method       { shift->{number} }

=head2 new

Create a new L<Net::Async::Blockchain::Block> instance

=over 4

=item * C<currency> Currency symbol

=item * C<number> block number

=back

L<Net::Async::Blockchain::Block>

=cut

sub new {
    my ($class, %params) = @_;
    my $self = bless {}, $class;

    foreach (qw(number currency)) {
        $self->{$_} = delete $params{$_} if exists $params{$_};
    }

    die "Invalid block parameters" if keys %params;
    return $self;
}

=head2 clone

Clone the self object and the attribute values

=over 4

=back

new L<Net::Async::Blockchain::Block> based on self

=cut

sub clone {
    my ($self) = @_;
    my $clone = Net::Async::Blockchain::Block->new();
    @{$clone}{keys %$self} = values %$self;
    return $clone;
}

1;
