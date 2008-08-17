use strict;

use FindBin qw/$Bin/;
use lib '$Bin/../lib';
use SkypeAPI::Robot;
use Data::Dumper;



SkypeAPI::Robot->new->run();



