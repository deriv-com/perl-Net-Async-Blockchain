package Net::Async::Blockchain::Config;

use strict;
use warnings;
no indirect;

our $VERSION = '0.001';

use Moo;
use List::Util qw(any);
use Ryu::Async;

use constant REQUIRED => [qw(host port)];

has source => (
    is => 'ro',
);

has config => (
    is      => 'rw',
    default => sub { {} });

sub configure {
    my ($self, $args) = @_;
    return unless is_valid_configuration($args);
    $self->config->{host}              = $args->{host};
    $self->config->{port}              = $args->{port};
    $self->config->{subscription_port} = $args->{subscription_port};
    $self->config->{user}              = $args->{user} if defined $args->{user};
    $self->config->{password}          = $args->{password} if defined $args->{password};
    $self->config->{subscription_url}  = sprintf("%s:%s", $self->config->{host}, $self->config->{subscription_port});
    $self->config->{rpc_url}           = sprintf("%s:%s", $self->config->{host}, $self->config->{port});
    $self->config->{rpc_url}           = sprintf("%s:%s@%s", $self->config->{user}, $self->config->{password}, $self->config->{rpc_url})
        if $self->config->{user} && $self->config->{password};
}

sub is_valid_configuration {
    my ($configuration) = @_;

    for my $required (@{ +REQUIRED }) {
        return 0 unless any { $_ eq $required && defined $configuration->{$required} } keys $configuration->%*;
    }
    return 1;
}

1;

