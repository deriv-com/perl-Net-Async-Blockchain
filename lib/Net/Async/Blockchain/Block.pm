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

sub message_type { shift->{message_type} }
sub currency     { shift->{currency} }
sub number       { shift->{number} }

=head2 new

Create a new L<Net::Async::Blockchain::Block> instance

=over 4

=item * C<message_type> Message Type
=item * C<currency> Currency Symbol
=item * C<number> Block Number

=back

L<Net::Async::Blockchain::Block>

=cut

sub new {
    my ($class, %params) = @_;
    my $self = bless {}, $class;

    $self->{message_type} = 'block';

    foreach (qw(message_type number currency)) {
        $self->{$_} = delete $params{$_} if exists $params{$_};
    }

    die "Invalid block parameters" if keys %params;
    return $self;
}

1;
