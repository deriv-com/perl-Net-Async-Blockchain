package Net::Async::Blockchain::Client::RPC::ETH;

use strict;
use warnings;
no indirect;

our $VERSION = '0.001';

use parent qw(Net::Async::Blockchain::Client::RPC);

=head2 call

https://github.com/ethereum/wiki/wiki/JSON-RPC#eth_call

=over 4

=back

L<Future>

=cut

sub call {
    my ($self, @params) = @_;
    return $self->_request('eth_call', @params);
}

=head2 get_transaction_receipt

https://github.com/ethereum/wiki/wiki/JSON-RPC#eth_gettransactionreceipt

=over 4

=back

L<Future>

=cut

sub get_transaction_receipt {
    my ($self, @params) = @_;
    return $self->_request('eth_getTransactionReceipt', @params);
}

=head2 accounts

https://github.com/ethereum/wiki/wiki/JSON-RPC#eth_accounts

=over 4

=back

L<Future>

=cut

sub accounts {
    my ($self) = @_;
    return $self->_request('eth_accounts');
}

=head2 get_block_by_hash

https://github.com/ethereum/wiki/wiki/JSON-RPC#eth_getblockbyhash

=over 4

=back

L<Future>

=cut

sub get_block_by_hash {
    my ($self, @params) = @_;
    return $self->_request('eth_getBlockByHash', @params);
}

1;

