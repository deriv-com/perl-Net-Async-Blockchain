package Net::Async::Blockchain::Client::RPC::BTC;

use strict;
use warnings;
no indirect;

our $VERSION = '0.001';

use parent qw(Net::Async::Blockchain::Client::RPC);

=head2 get_transaction

https://bitcoin-rpc.github.io/en/doc/0.17.99/rpc/wallet/gettransaction/

=over 4

=back

L<Future>

=cut

sub get_transaction {
    my ($self, @params) = @_;
    return $self->_request('gettransaction', @params);
}

=head2 get_block

https://bitcoin-rpc.github.io/en/doc/0.17.99/rpc/wallet/getblock/

=over 4

=back

L<Future>

=cut

sub get_block {
    my ($self, @params) = @_;
    return $self->_request('getblock', @params);
}

1;

