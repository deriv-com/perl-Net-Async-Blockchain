package Net::Async::Blockchain::Client::RPC;

use strict;
use warnings;

our $VERSION = '0.001';

=head1 NAME

Net::Async::Blockchain::Client::RPC - Async RPC Client.

=head1 SYNOPSIS

    my $loop = IO::Async::Loop->new();

    $loop->add(
        my $http_client = Net::Async::Blockchain::Client::RPC->new(rpc_url => 'http://127.0.0.1:8332', rpc_timeout => 100)
    );

    my $response = $http_client->getblockchaininfo()->get;

    print $response->{blocks};

=head1 DESCRIPTION

Auto load the commands as the method parameters for the RPC calls returning them asynchronously.

=over 4

=cut

no indirect;

use Net::Async::HTTP;
use JSON::MaybeUTF8 qw(encode_json_utf8 decode_json_utf8);
use IO::Async::Notifier;

use parent qw(IO::Async::Notifier);

# default value for the Net::Async::HTTP stall_timeout configuration.
use constant DEFAULT_RPC_TIMEOUT => 100;

sub rpc_url : method { shift->{rpc_url} }

# this value will be set on the _init method, if not set will use the
# DEFAULT_RPC_TIMEOUT constant.
sub rpc_timeout : method { shift->{rpc_timeout} }

sub http_client : method {
    my ($self) = @_;

    return $self->{http_client} if $self->{http_client};

    $self->add_child(
        my $http_client = Net::Async::HTTP->new(
            decode_content => 1,
            stall_timeout  => $self->rpc_timeout // DEFAULT_RPC_TIMEOUT,
            fail_on_error  => 1,
        ));

    $self->{http_client} = $http_client;
    return $self->{http_client};
}

=head2 configure

Any additional configuration that is not described on L<IO::ASYNC::Notifier>
must be included and removed here.

=over 4

=item * C<rpc_url>

=item * C<rpc_timeout>

=back

=cut

sub configure {
    my ($self, %params) = @_;

    for my $k (qw(rpc_url rpc_timeout)) {
        $self->{$k} = delete $params{$k} if exists $params{$k};
    }

    $self->SUPER::configure(%params);
}

=head2 AUTOLOAD

Use any argument as the method parameter for the client RPC call

=over 4

=item * C<method>

=item * C<params> (any parameter required by the RPC call)

=back

=cut

sub AUTOLOAD {
    my $self = shift;

    my $method = $Net::Async::Blockchain::Client::RPC::AUTOLOAD;
    $method =~ s/.*:://;

    return if ($method eq 'DESTROY');

    my $obj = {
        id     => 1,
        method => $method,
        params => (ref $_[0] ? $_[0] : [@_]),
    };

    return $self->http_client->POST($self->rpc_url, encode_json_utf8($obj), content_type => 'application/json')->transform(
        done => sub {
            decode_json_utf8(shift->decoded_content)->{result};
        }
    )->else(
        sub {
            Future->fail(@_);
        });
}

1;
