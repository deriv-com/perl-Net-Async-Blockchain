package Net::Async::Blockchain;

use strict;
use warnings;
no indirect;

use IO::Async::Loop;
use Ryu::Async;
use Module::PluginFinder;

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

1;

