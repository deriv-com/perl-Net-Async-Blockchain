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

use parent qw(IO::Async::Notifier);

sub rpc_url : method                  { shift->{rpc_url} }
sub rpc_timeout : method              { shift->{rpc_timeout} }
sub rpc_user : method                 { shift->{rpc_user}     || undef }
sub rpc_password : method             { shift->{rpc_password} || undef }
sub subscription_url : method         { shift->{subscription_url} }
sub subscription_timeout : method     { shift->{subscription_timeout} }
sub subscription_msg_timeout : method { shift->{subscription_msg_timeout} }

=head2 configure

Any additional configuration that is not described on L<IO::Async::Notifier>
must be included and removed here.

=over 4

=item * C<rpc_url> RPC complete URL
=item * C<rpc_timeout> RPC timeout
=item * C<rpc_user> RPC user. (optional, default: undef)
=item * C<rpc_password> RPC password. (optional, default: undef)
=item * C<subscription_url> Subscription URL it can be TCP for ZMQ and WS for the Websocket subscription
=item * C<subscription_timeout> Subscription connection timeout
=item * C<subscription_msg_timeout> Subscription interval between messages timeout

=back

=cut

sub configure {
    my ($self, %params) = @_;

    for my $k (qw(rpc_url rpc_timeout rpc_user rpc_password subscription_url subscription_timeout subscription_msg_timeout)) {
        $self->{$k} = delete $params{$k} if exists $params{$k};
    }

    $self->SUPER::configure(%params);
}

1;
