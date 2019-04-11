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

use parent qw(IO::Async::Notifier);

sub rpc_url : method             { shift->{rpc_url} }
sub rpc_timeout : method         { shift->{rpc_timeout} }
sub subscription_url : method    { shift->{subscription_url} }
sub lookup_transactions : method { shift->{lookup_transactions} }

=head2 configure

Any additional configuration that is not described on L<IO::ASYNC::Notifier>
must be included and removed here.

=over 4

=item * C<rpc_url> RPC complete URL
=item * C<rpc_timeout> RPC timeout
=item * C<subscription_url> Subscription URL it can be TCP for ZMQ and WS for the Websocket subscription
=item * C<lookup_transactions> How many transactions will be included in the search to check if the subscription transactions is owned by the node

=back

=cut

sub configure {
    my ($self, %params) = @_;

    for my $k (qw(rpc_url rpc_timeout subscription_url lookup_transactions)) {
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
        $self->add_child(my $source = Ryu::Async->new);
        $self->{source} = $source->source;
        return $self->{source};
    }
}

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
        $self->add_child(my $http_client = Net::Async::Blockchain::Client::RPC->new(rpc_url => $self->rpc_url));
        return $http_client;
    }
}

1;

