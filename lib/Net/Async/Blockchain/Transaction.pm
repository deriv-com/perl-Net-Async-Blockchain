package Net::Async::Blockchain::Transaction;

use strict;
use warnings;
no indirect;

our $VERSION = '0.001';

use Moo;
use Type::Tiny;

my $TXN_TYPE = "Type::Tiny"->new(
    name       => "TransactionType",
    constraint => sub { $_ && $_ =~ /^(?:receive|sent|internal)$/ },
    message    => sub { "Invalid transaction type (" . ($_ // 'undefined') . ")." },
);

my $VALID_BIG_FLOAT = "Type::Tiny"->new(
    name => "ValidBigFloatType",
    constraint => sub { $_ && ref $_ eq 'Math::BigFloat' && !$_->is_nan() },
    message    => sub { "Invalid Math::BigFloat type (" . ($_ // 'undefined') . ")." },
);

has 'currency' => (
    required => 1,
);

has 'hash' => (
    required => 1,
);

has 'from' => ();

has 'to' => (
    required => 1,
);

has 'contract' => ();

has 'amount' => (
    required => 1,
    isa => $VALID_BIG_FLOAT.
);

has 'fee' => (
    required => 1,
    isa => $VALID_BIG_FLOAT,
);

has 'fee_currency' => (
    required => 1,
);

has 'type' => (
    isa => $TXN_TYPE,
);

sub clone { $self->meta->clone_object($self) }

1;

