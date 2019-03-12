package Net::Async::Blockchain::Client::RPC;

use strict;
use warnings;
no indirect;

use Moo;
use IO::Async::Loop;
use Net::Async::HTTP;
use JSON::MaybeUTF8 qw(encode_json_utf8 decode_json_utf8);

has url => (
    is => 'ro',
);

has _loop => (
    is => 'lazy',
);

sub _build__loop {
    return IO::Async::Loop->new();
}

has _http_client => (
    is => 'lazy',
);

sub _build__http_client {
    my ($self) = @_;
    $self->_loop->add(
        my $http_client = Net::Async::HTTP->new(
            decode_content => 1,
        ));
    return $http_client;
}

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

    return $self->get_json_response(
        "POST" => $self->url,
        encode_json_utf8($obj),
        content_type => 'application/json',
    );
}

sub get_json_response {
    my ($self, $method, @params) = @_;
    $self->_http_client->$method(@params)->transform(
        done => sub {
            my ($resp) = @_;
            decode_json_utf8($resp->decoded_content)->{result};
        }
        )->else(
        sub {
            Future->fail(@_);
        });
}

1;
