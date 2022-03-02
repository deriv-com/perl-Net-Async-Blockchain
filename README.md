
# perl-Net-Async-Blockchain

Support for subscriptions and API interaction with blockchains such as BTC or ETH

## SYNOPSIS

```perl
my $loop = IO::Async::Loop->new;

$loop->add(
	my $btc_client = Net::Async::Blockchain::BTC->new(
		blockchain_code 		 => 'Bitcoin',
		subscription_url         => 'tcp://127.0.0.1:28332',
		subscription_timeout     => 100,
		subscription_msg_timeout => 3600000,
));

$btc_client->subscribe("blocks")->each(sub { print shift->{hash})->get;
```

## Supported cryptocurrencies:

- BTC (also LTC and BCH)
- Omnicore (Tether, ...)
- ETH (also ERC20 contracts)

## Supported subscriptions:

### Blocks:
- Call: `->subscribe('blocks');`
- BTC, LTC, BCH, Omnicore
	- `hashblock`
- ETH, ERC20
	- `newHeads`

## CAVEATS

This software is in an early state.

REQUIREMENTS

-   perl 5

## See also
- [perl-Ethereum-RPC-Client](https://github.com/binary-com/perl-Ethereum-RPC-Client)

## Author
Binary.com

## LICENSE

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
