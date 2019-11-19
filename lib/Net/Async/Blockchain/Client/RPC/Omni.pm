package Net::Async::Blockchain::Client::RPC::Omni;

use strict;
use warnings;

our $VERSION = '0.001';

=head1 NAME

Net::Async::Blockchain::Client::RPC::Omni - Async Omnicore RPC Client.

=head1 SYNOPSIS

    my $loop = IO::Async::Loop->new();

    $loop->add(
        my $http_client = Net::Async::Blockchain::Client::RPC::Omni->new(endpoint => 'http://127.0.0.1:8332', timeout => 100)
    );

    my $response = $http_client->get_transaction('txid...')->get;

=head1 DESCRIPTION

Omnicore based RPC calls

=over 4

=back

=cut

no indirect;

use parent qw(Net::Async::Blockchain::Client::RPC::BTC);

=head2 get_transaction

https://github.com/OmniLayer/omnicore/blob/master/src/omnicore/doc/rpc-api.md#omni_gettransaction

=over 4

=back

L<Future>

=cut

sub get_transaction {
    my ($self, @params) = @_;
    return $self->_request('omni_gettransaction', @params);
}

=head2 get_detail_transaction

https://bitcoin-rpc.github.io/en/doc/0.17.99/rpc/wallet/gettransaction/

=cut

sub get_detail_transaction {
    my ($self, @params) = @_;
    return $self->_request('gettransaction', @params);
}

1;

