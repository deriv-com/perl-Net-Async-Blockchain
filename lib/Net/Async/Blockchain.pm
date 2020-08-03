package Net::Async::Blockchain;

use strict;
use warnings;

our $VERSION = '0.001';

=head1 NAME

Net::Async::Blockchain - base for blockchain subscription clients.

=head1 SYNOPSIS

Objects of this type would not normally be constructed directly.

For blockchain clients see:
- Net::Async::Blockchain::BTC
- Net::Async::BLockchain::ETH

Which will use this class as base.

=head1 DESCRIPTION

This module contains methods that are shared by the subscription clients.

=over 4

=back

=cut

no indirect;

use Ryu::Async;
use Net::Async::Blockchain::Block;

use parent qw(IO::Async::Notifier);

sub rpc_url : method                  { shift->{rpc_url} }
sub rpc_timeout : method              { shift->{rpc_timeout} }
sub subscription_url : method         { shift->{subscription_url} }
sub subscription_timeout : method     { shift->{subscription_timeout} }
sub subscription_msg_timeout : method { shift->{subscription_msg_timeout} }
sub currency_symbol : method          { shift->{currency_symbol} }
sub base_block_number : method        { shift->{base_block_number} }

=head2 configure

Any additional configuration that is not described on L<IO::Async::Notifier>
must be included and removed here.

=over 4

=item * C<rpc_url> RPC complete URL
=item * C<rpc_timeout> RPC timeout
=item * C<subscription_url> Subscription URL it can be TCP for ZMQ and WS for the Websocket subscription
=item * C<subscription_timeout> Subscription connection timeout
=item * C<subscription_msg_timeout> Subscription interval between messages timeout
=item * C<currency_symbol> Currency symbol
=item * C<base_block_number> Block number where the subscription must apply the recursive search from

=back

=cut

sub configure {
    my ($self, %params) = @_;

    for my $k (qw(rpc_url rpc_timeout subscription_url subscription_timeout subscription_msg_timeout currency_symbol base_block_number)) {
        $self->{$k} = delete $params{$k} if exists $params{$k};
    }

    $self->SUPER::configure(%params);
}

=head2 source

Create an L<Ryu::Source> instance, if it is already defined just return
the object

=over 4

=back

L<Ryu::Source>

=cut

sub source : method {
    my ($self) = @_;
    return $self->{source} //= do {
        $self->add_child(my $ryu = Ryu::Async->new);
        $ryu->source;
    };
}

=head2 block

create a block object to store the base block number value

=over 4

=back

Returns L<Net::Async::Blockchain::Block>

=cut

sub block {
    my ($self) = @_;

    return $self->{block} //= do {
        Net::Async::Blockchain::Block->new(
            number   => $self->base_block_number,
            currency => $self->currency_symbol
        );
        }
}

1;

