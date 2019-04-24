package Net::Async::Blockchain::Client::RPC;

use strict;
use warnings;

our $VERSION = '0.001';

=head1 NAME

Net::Async::Blockchain::Client::RPC - Async RPC Client.

=head1 SYNOPSIS

    my $loop = IO::Async::Loop->new();

    $loop->add(
        my $http_client = Net::Async::Blockchain::Client::RPC->new(endpoint => 'http://127.0.0.1:8332', timeout => 100)
    );

    my $response = $http_client->getblockchaininfo()->get;

    print $response->{blocks};

=head1 DESCRIPTION

Auto load the commands as the method parameters for the RPC calls returning them asynchronously.

=over 4

=back

=cut

no indirect;

use Net::Async::HTTP;
use JSON::MaybeUTF8 qw(encode_json_utf8 decode_json_utf8);
use IO::Async::Notifier;

use parent qw(IO::Async::Notifier);

# default value for the Net::Async::HTTP stall_timeout configuration.
use constant DEFAULT_TIMEOUT => 100;

sub endpoint : method { shift->{endpoint} }

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
                fail_on_error  => 1,
            ));

        $self->{http_client} = $http_client;
        return $self->{http_client};
        }
}

=head2 configure

Any additional configuration that is not described on L<IO::Async::Notifier>
must be included and removed here.

=over 4

=item * C<endpoint>

=item * C<timeout> connection timeout (seconds)

=back

=cut

sub configure {
    my ($self, %params) = @_;

    for my $k (qw(endpoint timeout)) {
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
    my ($self, @params) = @_;

    my $method = $Net::Async::Blockchain::Client::RPC::AUTOLOAD;
    $method =~ s/.*:://;

    return if ($method eq 'DESTROY');

    my $obj = {
        id     => 1,
        method => $method,
        params => [@params],
    };

    return $self->http_client->POST($self->endpoint, encode_json_utf8($obj), content_type => 'application/json')->transform(
        done => sub {
            decode_json_utf8(shift->decoded_content)->{result};
        }
        )->else(
        sub {
            Future->fail(@_);
        });
}

1;
