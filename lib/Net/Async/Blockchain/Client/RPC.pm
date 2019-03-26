package Net::Async::Blockchain::Client::RPC;

use strict;
use warnings;
no indirect;

use Net::Async::HTTP;
use JSON::MaybeUTF8 qw(encode_json_utf8 decode_json_utf8);
use IO::Async::Notifier;

use parent qw(IO::Async::Notifier);

use constant DEFAULT_TIMEOUT => 100;

sub endpoint : method { shift->{endpoint} }

sub timeout : method {shift->{timeout}}

sub _init {
    my ($self, $paramref) = @_;
    $self->SUPER::_init;

    for my $k (qw(endpoint timeout)) {
        $self->{$k} = delete $paramref->{$k} if exists $paramref->{$k};
    }
}

sub AUTOLOAD {
    my $self = shift;

    my $method = $Net::Async::Blockchain::Client::RPC::AUTOLOAD;
    $method =~ s/.*:://;

    return if ($method eq 'DESTROY');

    $self->add_child(
        my $http_client = Net::Async::HTTP->new(
            decode_content => 1,
            stall_timeout => $self->timeout // DEFAULT_TIMEOUT,
            fail_on_error => 1,
    ));

    my $obj = {
        id     => 1,
        method => $method,
        params => (ref $_[0] ? $_[0] : [@_]),
    };

    return $http_client->POST($self->endpoint, encode_json_utf8($obj), content_type => 'application/json')->transform(
        done => sub {
            decode_json_utf8(shift->decoded_content)->{result};
        })->else(sub {
            Future->fail(@_);
        });
}

1;
