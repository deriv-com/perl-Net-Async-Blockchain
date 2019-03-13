package Net::Async::Blockchain::Client;

use strict;
use warnings;
no indirect;

our $VERSION = '0.001';

use base qw( Exporter );
our @EXPORT_OK = qw(filter);

use IO::Async::Loop;
use Ryu::Async;
use Module::PluginFinder;

sub _filter {
    my ($self, $path) = @_;

    return Module::PluginFinder->new(
        search_path => 'Net::Async::Blockchain::Currency',
        filter      => sub {
            my ($module, $currency_code) = @_;
            return 0
                unless $currency_code
                && $module->can('currency_code')
                && $currency_code eq $module->currency_code();
            return 1;
        },
    );
}

sub new {
    my ($self, $currency_code, $args) = @_;
    return undef unless $currency_code;

    my $currency = $self->_filter->construct($currency_code);
    if($currency){
        my $loop = IO::Async::Loop->new;
        $loop->add(my $ryu = Ryu::Async->new);
        return $currency->new(source => $ryu->source, config => $args);
    }
    return undef;
}

1;

