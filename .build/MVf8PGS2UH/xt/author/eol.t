use strict;
use warnings;

# this test was generated with Dist::Zilla::Plugin::Test::EOL 0.19

use Test::More 0.88;
use Test::EOL;

my @files = (
    'lib/Net/Async/Blockchain.pm',                   'lib/Net/Async/Blockchain/BTC.pm',
    'lib/Net/Async/Blockchain/Client/RPC.pm',        'lib/Net/Async/Blockchain/Client/RPC/BTC.pm',
    'lib/Net/Async/Blockchain/Client/RPC/ETH.pm',    'lib/Net/Async/Blockchain/Client/RPC/Omni.pm',
    'lib/Net/Async/Blockchain/Client/Websocket.pm',  'lib/Net/Async/Blockchain/Client/ZMQ.pm',
    'lib/Net/Async/Blockchain/ETH.pm',               'lib/Net/Async/Blockchain/Omni.pm',
    'lib/Net/Async/Blockchain/Plugins/ETH/ERC20.pm', 'lib/Net/Async/Blockchain/Plugins/ETH/Utility.pm',
    'lib/Net/Async/Blockchain/Transaction.pm',       't/00-check-deps.t',
    't/00-compile.t',                                't/00-report-prereqs.dd',
    't/00-report-prereqs.t',                         't/eth.t',
    't/rc/.perlcriticrc',                            't/rc/.perltidyrc',
    't/rpc.t',                                       't/websocket.t',
    't/zmq.t'
);

eol_unix_ok($_, {trailing_whitespace => 1}) foreach @files;
done_testing;
