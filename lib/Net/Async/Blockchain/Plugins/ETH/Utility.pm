package Net::Async::Blockchain::Plugins::ETH::Utility;

use strict;
use warnings;
no indirect;

our $VERSION = '0.001';

use Math::BigFloat;

sub enabled { return 0 }

=head2 _remove_zeros

The address on the topic logs is always a 32 bytes string so we will
have addresses like: `000000000000000000000000c636d4c672b3d3760b2e759b8ad72546e3156ce9`

We need to remove all the extra zeros and add the `0x`

=over 4

=item * C<trxn_topic> The log string

=back

string

=cut

sub _remove_zeros {
    my ($self, $trxn_topic) = @_;

    # get only the last 40 characters from the string (ETH address size).
    my $address = substr($trxn_topic, -40, length($trxn_topic));

    return "0x$address";
}

=head2 _to_string

The response from the contract will be in the dynamic type format when we call the symbol, so we will
have a response like: `0x00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000003414c480000000000000000000000000000000000000000000000000000000000`

This is basically:

First 32 bytes: 0000000000000000000000000000000000000000000000000000000000000020 = 32 (offset to start of data part of second parameter)
Second 32 bytes: 0000000000000000000000000000000000000000000000000000000000000003 = 3 (value size)
Third 32 bytes: 414c480000000000000000000000000000000000000000000000000000000000 = ALH (padded left value)

=over 4

=item * C<trxn_topic> The log string

=back

string

=cut

sub _to_string {
    my ($self, $response) = @_;

    return undef unless $response;

    $response = substr($response, 2) if $response =~ /^0x/;

    # split every 32 bytes
    my @chunks = $response =~ /(.{1,64})/g;

    return undef unless scalar @chunks >= 3;

    # position starting from the second item
    my $position = Math::BigFloat->from_hex($chunks[0])->bdiv(32)->badd(1)->bint();

    # size
    my $size = Math::BigFloat->from_hex($chunks[1])->bint();

    # hex string to string
    my $packed_response = pack('H*', $chunks[$position]);

    # substring by the data size
    return substr($packed_response, 0, $size);
}

1;

