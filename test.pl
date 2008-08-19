#!perl

use strict;

use lib './lib';

use SkypeAPI;
use Data::Dumper;
use SkypeAPI::Command;


my $skype = SkypeAPI->new();
print " skype available=", $skype->attach , "\n";
my $command = $skype->create_command( { string => "GET USERSTATUS"}  );
print  $skype->send_command($command) , "\n";
$command = $skype->create_command( { string => "SEARCH CHATS"}  );
print $skype->send_command($command) , "\n";

$skype->register_handler(\&handler);



sub handler {
    my $skype = shift;
    my $msg = shift;
    my $command = $self->create_command( { string => "GET USERSTATUS"}  );
    print $self->send_command($command) , "\n";
}


$skype->listen();
