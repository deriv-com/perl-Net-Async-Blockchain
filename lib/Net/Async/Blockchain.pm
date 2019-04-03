package Net::Async::Blockchain;

use strict;
use warnings;
no indirect;

use IO::Async::Loop;
use Ryu::Async;

use base qw(IO::Async::Notifier);

sub config : method { shift->{config} }

sub _init {
    my ($self, $paramref) = @_;
    $self->SUPER::_init;

    $self->{config} = delete $paramref->{config} if exists $paramref->{config};
}

sub source : method {
    my ($self) = @_;
    return $self->{source} if $self->{source};
    $self->loop->add(my $source = Ryu::Async->new);
    $self->{source} = $source->source;
    return $self->{source};
}

sub rpc_client : method {
    my ($self) = @_;
    return $self->{rpc_client} if $self->{rpc_client};

    $self->add_child(
        my $http_client = Net::Async::Blockchain::Client::RPC->new(endpoint => $self->config->{rpc_url})
    );

    return $http_client;
}

1;

