package Net::Async::Blockchain::Config;

use strict;
use warnings;
no indirect;

use Moo;

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

