package SkypeAPI::Robot;

use strict;
use warnings;

use SkypeAPI;
use XiaoI;
use Data::Dumper;
our $VERSION = '0.02';

my $instance = undef;

sub new {
    my $class = shift;
    my $opt = shift;
    
    return $instance if $instance;
    
    $instance = {opt => $opt};
    bless $instance, $class;
    $instance->{robot_list} = {};
    

    return $instance;
}

sub mesasge_listener {
    my ($skype, $message_id) = @_;
    
    print "I received message $message_id\n";
     my $CHATNAME  = $skype->get_message($message_id, 'CHATNAME');
    print "CHATNAME :$CHATNAME \n";
    
    if (not exists $instance->{robot_list}->{ $CHATNAME }) {
        print "CREAET NEW ROBOT FOR THE CHAT\n";
        my $robot = XiaoI->new;
        $instance->{robot_list}->{$CHATNAME} = $robot;
    }
    
    my $body = $skype->get_message($message_id, 'body');
    print "body:$body\n";    
   
   
    my $robot = $instance->{robot_list}->{$CHATNAME};
    my $text = $robot->get_robot_text($body);
    $skype->send_chat_message($CHATNAME, $text);
    
    return 1;
}



sub run {
    my $self = shift;   
    
    my $skype = SkypeAPI->new({is_verbose =>0});
    sleep 1;
    
    my $listener = $skype->add_message_listener(\&mesasge_listener, 1);
    $skype->message_listen();
}


1;
