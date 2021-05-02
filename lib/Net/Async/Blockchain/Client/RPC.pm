package Net::Async::Blockchain::Client::RPC;

use strict;
use warnings;

our $VERSION = '0.001';

=head1 NAME

Net::Async::Blockchain::Client::RPC - Async RPC Client.

=head1 SYNOPSIS

Objects of this type would not normally be constructed directly.

=head1 DESCRIPTION

Centralize all asynchronous RPC calls.

=over 4

=back

=cut

no indirect;

use Future::AsyncAwait;
use Net::Async::HTTP;
use JSON::MaybeUTF8 qw(encode_json_utf8 decode_json_utf8);
use IO::Async::Notifier;
use Syntax::Keyword::Try;

use parent qw(IO::Async::Notifier);

# default value for the Net::Async::HTTP stall_timeout configuration.
use constant DEFAULT_TIMEOUT => 100;

sub endpoint : method     { shift->{endpoint} }
sub rpc_user : method     { shift->{rpc_user}     || undef }
sub rpc_password : method { shift->{rpc_password} || undef }

# this value will be set on the _init method, if not set will use the
# DEFAULT_TIMEOUT constant.
sub timeout : method { shift->{timeout} // DEFAULT_TIMEOUT }

=head2 http_client

Create an L<Net::Async::HTTP> instance, if it is already defined just return
the object

=over 4

=back

L<Net::Async::HTTP>

=cut

sub http_client : method {
    my ($self) = @_;

    return $self->{http_client} //= do {
        $self->add_child(
            my $http_client = Net::Async::HTTP->new(
                decode_content => 1,
                stall_timeout  => $self->timeout,
                timeout        => $self->timeout,
            ));

        $http_client;
    };
}

=head2 configure

Any additional configuration that is not described on L<IO::Async::Notifier>
must be included and removed here.

=over 4

=item * C<endpoint>

=item * C<timeout> connection timeout (seconds)

=item * C<rpc_user> RPC user. (optional, default: undef)

=item * C<rpc_password> RPC password. (optional, default: undef)

=back

=cut

sub configure {
    my ($self, %params) = @_;

    for my $k (qw(endpoint rpc_user rpc_password timeout)) {
        $self->{$k} = delete $params{$k} if exists $params{$k};
    }

    $self->SUPER::configure(%params);
}

=head2 _request

Use any argument as the method parameter for the client RPC call

=over 4

=item * C<method>

=item * C<params> (any parameter required by the RPC call)

=back

L<Future>

=cut

async sub _request {
    my ($self, $method, @params) = @_;

    my $obj = {
        id     => 1,
        method => $method,
        params => [@params],
    };
    my @post_params = ($self->endpoint, encode_json_utf8($obj), content_type => 'application/json');
    # for ETH based, we don't require user+password. Check to send user+password if exists.
    push @post_params, (user => $self->rpc_user)     if $self->rpc_user;
    push @post_params, (pass => $self->rpc_password) if $self->rpc_password;

    try {
        my $response = await $self->http_client->POST(@post_params);
        return decode_json_utf8($response->decoded_content)->{result};
    } catch ($e) {
        return (undef, $e);
    }
}

1;
