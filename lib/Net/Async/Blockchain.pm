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

=cut

no indirect;

use IO::Async::Loop;
use Ryu::Async;

use base qw(IO::Async::Notifier);

sub config : method { shift->{config} }

=head2 _init

Called by `new` before `configure`, any additional configuration
that is not described on IO::ASYNC::Notifier must be included and
removed here.

=over 4

=item *

C<config> Expected to be a hash containing:

rpc_url (required, ex.: http://127.0.0.1:8332)
rpc_timeout (optional, ex.: 100)
subscription_url (required, ex.: ws://127.0.0.1:28332)

=back

=cut

sub _init {
    my ($self, $paramref) = @_;
    $self->SUPER::_init;

    $self->{config} = delete $paramref->{config} if exists $paramref->{config};
}

=pod

=head2 source

The final client source, once a client have subscribed to any client
this source will be returned.

Created only the first time, if it's required again use the same source.

=back

L<Ryu::Source>

=cut


sub source : method {
    my ($self) = @_;
    return $self->{source} if $self->{source};
    $self->loop->add(my $source = Ryu::Async->new);
    $self->{source} = $source->source;
    return $self->{source};
}

=pod

=head2 rpc_client

Returns a new async RPC client.

Created only the first time, if it's required again use the same client.

=back

L<Net::Async::Blockchain::Client::RPC>

=cut

sub rpc_client : method {
    my ($self) = @_;
    return $self->{rpc_client} if $self->{rpc_client};

    $self->add_child(
        my $http_client = Net::Async::Blockchain::Client::RPC->new(rpc_url => $self->config->{rpc_url})
    );

    return $http_client;
}

1;

