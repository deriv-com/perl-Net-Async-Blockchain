package Net::Async::Blockchain::Client::RPC::BTC;

use strict;
use warnings;

our $VERSION = '0.001';

=head1 NAME

Net::Async::Blockchain::Client::RPC::BTC - Async BTC RPC Client.

=head1 SYNOPSIS

    my $loop = IO::Async::Loop->new();

    $loop->add(
        my $http_client = Net::Async::Blockchain::Client::RPC::BTC->new(endpoint => 'http://127.0.0.1:8332', timeout => 100)
    );

    my $response = $http_client->accounts()->get;

=head1 DESCRIPTION

BTC based RPC calls

=over 4

=back

=cut

no indirect;

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

