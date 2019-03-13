package Net::Async::Blockchain::Config;

use strict;
use warnings;
no indirect;

our $VERSION = '0.001';

use Moo;
use List::Util qw(any);
use Ryu::Async;

has loop => (
    is => 'ro',
);

has source => (
    is => 'ro',
);

has config => (
    is => 'ro',
);

1;

