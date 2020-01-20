#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;
use Test::MockModule;
use Future::AsyncAwait;
use Net::Async::Blockchain::Transaction;
use Net::Async::Blockchain::Omni;
use Net::Async::Blockchain::Client::RPC::Omni;
use IO::Async::Loop;
use BOM::CTC::Currency;

subtest 'Test: Subroutines' => sub {
    my $currency = BOM::CTC::Currency->new(
        currency_code => 'UST',
        broker_code   => 'CR'
    );
    my $loop = IO::Async::Loop->new();
    $loop->add(my $subscription = $currency->subscription());
    
    my $internal_address = '2NGUxWLNv34PuxYQHmnsPWJATxWPdh5qRDv';
    my $external_address = '2NG4vwyZ9j4TZtzUfs7cLN8PFBDqfx9gnbA';
    
    note "sub list_by_addresses";
    my $list_by_internal =  $subscription->rpc_client->list_by_addresses('2NGUxWLNv34PuxYQHmnsPWJATxWPdh5qRDv')->get;
    is @$list_by_internal, 1, 'There should be response by internal address.';
    my $list_by_external =  $subscription->rpc_client->list_by_addresses('2NG4vwyZ9j4TZtzUfs7cLN8PFBDqfx9gnbA')->get;
    is @$list_by_external, 0, 'There should be NO response by external address.';
    
    
    note "sub mapping_address";
    my $omni_gettransaction = {
        subsends => [{
                amount     => Math::BigFloat->new(1837.74104797),
                propertyid => 31
            }
        ],
        txid             => 'e915c8b0808eb26ba41e8c71e7174a8175a7cddf4c882f81c971d1903816586',
        block            => Math::BigInt->new(608451),
        sendingaddress   => $internal_address,
        referenceaddress => $external_address,
        fee              => Math::BigFloat->new(0.00050000),
        type             => 'Send All',
        blocktime        => 1576551230,
    };
   
  my ($from,$to) = $subscription->mapping_address($omni_gettransaction)->get;
  is $from->{address}, $internal_address, 'The FROM address is correct.';
  is $to->{address}, $external_address, 'The TO address is correct.';
 
};


done_testing();