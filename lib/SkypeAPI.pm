package SkypeAPI;

use 5.008008;
use strict;
use warnings;
use Digest::MD5;
require Exporter;

our @ISA = qw(Exporter);
our $VERSION = '0.01';

require XSLoader;
XSLoader::load('SkypeAPI', $VERSION);

use Data::Dumper;
use Time::HiRes qw( sleep );

#for more api information, please goto https://developer.skype.com/Docs/ApiDoc/src


my $instance = undef;
sub new {
    my ($class, $opt) = @_;
    return $instance if $instance;
    $instance = {};
    bless $instance, $class;
    $instance->{result_list} = {};
    $instance->{opt}= $opt;
    $instance->{message_listener}= [];
    $instance->{message_queue}= [];
    $opt->{copy_data} = \&copy_data;
    if ( not $instance->init($opt) ) {
        die "cannot init skype\n";
    }

    return $instance;
}




sub add_message_listener {
    my ($instance, $listener, $using_api) = @_;
    push @{$instance->{message_listener}}, { callback => $listener, using_api => $using_api || 0};
    return scalar @{$instance->{message_listener}} - 1;
}

sub remove_message_listener {
    my ($instance, $listener_index) = @_;
    
    if (@{$instance->{message_listener}} == 0 or $listener_index > scalar @{$instance->{message_listener}} - 1) {
        return;
    }
    
    if ($listener_index == 0) {
        shift  @{$instance->{message_listener}};
        return;
    }
    
    if ($listener_index == scalar @{$instance->{message_listener}} - 1) {
        pop  @{$instance->{message_listener}};
        return;
    }
    
    @{$instance->{message_listener}} = (@{$instance->{message_listener}}[0..$listener_index - 1], @{$instance->{message_listener}}[$listener_index+1..scalar @{$instance->{message_listener}} - 1]);
}


sub copy_data {
    my ($message) = @_;
    print "[robot]$message\n" if $instance->{opt}->{is_verbose};
    
    if ($message =~ m{^#(\w+)\s+(.*)}is) {
        my ($id, $msg) = ($1, $2);
        print "[robot]get comand result: [$id]$msg\n" if $instance->{opt}->{is_verbose};
        if ($instance->{result_list}->{$id}) {
            $instance->{result_list}->{$id}->{result} = $msg;
        }
    } elsif (scalar @{$instance->{message_listener}} and $message =~ m{^MESSAGE\s+(\d+)\s+STATUS\s+RECEIVED}) {      
        my $message_id = $1;  
        
        for my $listener (@{$instance->{message_listener}}) {
            next if $listener->{using_api};
            
            my $result = $listener->{callback}->($instance, $message_id);
            next if $result == 0;
            return if $result == 1;
        }  
        
        push @{$instance->{message_queue}}, $message_id;  
    }
}

sub message_listen {
    my ($instance) = @_;
    LISTEN_LOOP:
    while (1) {
        while( my $message_id = shift @{$instance->{message_queue}}) {
            for my $listener (@{$instance->{message_listener}}) {
                next unless $listener->{using_api};
                my $result = $listener->{callback}->($instance, $message_id);
                next if $result == 0;
                last if $result == 1;
                last LISTEN_LOOP if $result == -1; #exit loop
            }
        }     
        sleep 1;   
    }
}




sub do_command {
    my ($instance, $message) = @_;
    
    $instance->send_message($message);
}


sub do_command_for_result {
    my ($instance, $message) = @_;
    my $id = substr(Digest::MD5::md5_hex(time), 0, 16);
    $instance->{result_list}->{$id} = {message => $message};
    $message = "#$id $message";
    
    $instance->send_message($message);
    return $id;
}

sub pop_command_result {
    my ($instance, $id) = @_;

    my $command_slot = $instance->{result_list}->{$id};
    if ($command_slot and $command_slot->{result}) {
        delete  $instance->{result_list}->{$id};
        return $command_slot->{result};
    }elsif ($command_slot) {
        return -1;
    } else {
        return -2;
    }
    
}


#belows are wrapped commands

sub wait_message {
    my ($instance, $cmd_id, $times, $interval) = @_;
    $times ||= 200;
    $interval ||= 0.05;
    for (1..$times) {
        my $result = $instance->pop_command_result($cmd_id);
        if ($result eq '-2') {
            printf("[error]$cmd_id:WAIT MESSAGE:return -2\n");
            return undef;
        }
        if ($result ne '-1') {
            return $result;
        }
        sleep($interval);
    }
    printf("[error]$cmd_id:WAIT MESSAGE:FAILED\n");
    return undef;
}

sub get_command {
    my ($instance, $want, @other) = @_;
    $want = uc($want);
    my $cmd_id = $instance->do_command_for_result("GET $want");
    my $message = $instance->wait_message($cmd_id, @other);
    if ($message and $message =~ m{^$want\s+(.*)}) {
        return $1;
    } else {
        printf("[error]$cmd_id:GET $want:$message\n");
        return undef;
    }
}


sub search_chats {
    my ($instance, $want, @other) = @_;
    $want = uc($want);
    my $cmd_id = $instance->do_command_for_result("SEARCH $want");
    my $message = $instance->wait_message($cmd_id, @other);
    if ($message and $message =~ m{^CHATS\s+(.*)}) {
        my $chats = $1;
        my @chats = split /,\s+/, $chats;
        return \@chats;
    } else {
        printf("[error]$cmd_id:SEARCH $want:$message\n");
        return undef;
    }
}


sub send_chat_message {
    my ($instance,$chat_id, $text, @other) = @_;
    my $cmd_id = $instance->do_command_for_result("CHATMESSAGE $chat_id $text");
    my $message = $instance->wait_message($cmd_id, @other);
    if ($message and $message =~ m{^MESSAGE\s+(.*)}) {       
        return $1;
    } else {
        printf("[error]$cmd_id:CHATMESSAGE $chat_id $text:$message\n");
        return undef;
    }
}

sub get_message {
    my ($instance, $message_id, $property, @other) = @_;
    $property = uc($property);
    my $cmd_id = $instance->do_command_for_result("GET CHATMESSAGE $message_id $property");
    my $message = $instance->wait_message($cmd_id, @other);
    if ($message and $message =~ m{^(?:CHAT|)MESSAGE\s+$message_id\s+$property\s+(.*)}) {       
        return $1;
    } else {
        printf("[error]$cmd_id:GET CHATMESSAGE $message_id $property:$message\n");
        return undef;
    }
}


# Preloaded methods go here.

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

SkypeAPI - Skype API simple implementation, only support windows platform now.

=head1 VERSION

0.01

=head1 SYNOPSIS

    use SkypeAPI;
    my $skype = SkypeAPI->new({is_verbose =>0});
    sleep 1;
    my $status = $skype->get_command('userstatus');
    print $status, "\n";
    my $version = $skype->get_command('skypeversion');
    print $version, "\n";
    my $currentuserhandle = $skype->get_command('currentuserhandle');
    print $currentuserhandle, "\n";
    my $FULLNAME = $skype->get_command('profile fullname');
    print $FULLNAME, "\n";
    
    #invoke the low level interface to send command
    my $cmd = 'GET USERSTATUS';
    $skype->do_command($cmd);
    #if you care about the result of the do_command
    my $cmd_id = $skype->do_command_for_result($cmd);
    my $result = $skype->wait_message($cmd_id);    
    
    #you can add/remove message listener, *DONT* call Skype API in the listener 
    my $listener = $skype->add_message_listener(\&mesasge_listener);
    $skype->remove_message_listener($listener);
    
    #if you want to call Skype API in your listener, you have to register your listener like this
    $skype->add_message_listener(\&mesasge_listener, 1);
    #and run into loop:
    $skype->message_listen();

=head1 FUNCTIONS

=head2 SkypeAPI->new( $opt )

Returns a SkypeAPI object. You can pass a option as a hashref when calling new.

    my $skype = SkypeAPI->new({is_verbose =>0});

=head2 SkypeAPI->do_command( $cmd_text )

Send command message to skype, if you are not care about the skype response.

    my $cmd = 'GET USERSTATUS';
    $skype->do_command($cmd);
    
=head2 SkypeAPI->do_command_for_result( $cmd_text )

Returns a command id. You can pass the command id when calling wait_message to get the response of skype.

    my $cmd = 'GET USERSTATUS';
    my $cmd_id = $skype->do_command_for_result($cmd);

=head2 SkypeAPI->wait_message( $cmd_id, [$wait_times, $sleep_interval] )

Watit and returns the response of the skype after calling do_command_for_result;

    my $result = $skype->wait_message($cmd_id);

Default the wait_times is 200, the sleep_interval is 0.1 seconds, this means, waiting for the response you have to wait 20 seconds at most.

=over

=item It returns -1 if the $cmd_id is not valid 

=item It returns -2 if the response not received yet.

=item It returns resonpse text if calling ok.

=back


=head2 SkypeAPI->add_message_listener( $ref_callback, [$using_api] )

Add listener to the chain of message listener, when message received, listeners in the chain will be invoke in turn.

If you are not going to use Skype API in your listener, you can add the listener like this:
    
    sub message_listener { 
        my ($instance, $message_id) = @_;
        return 1;
    }
    $skype->add_message_listener(\&mesasge_listener);

Usually you will DO call Skype API in your listener, you have to add the listener by passing a using_api flag and run into a message loop.
    
    sub message_listener { 
        my ($instance, $message_id) = @_;
        my $body = $instance->get_message($message_id, 'body');
        return 1;
    }
    my $listener = $skype->add_message_listener(\&mesasge_listener);
    $skype->message_listen();

You must take care about the return value of the listener

=over

=item Returns 1 if the listener DONOT want the other listeners in the chain to handle it.

=item Returns 0 if the listener allow the other listeners in the chain to handle it.

=item Returns -1 if the listener with the using_api flag want to stop the message loop.

=back

=head2 SkypeAPI->remove_message_listener( $listener)

Remove listener in the chain.

    my $listener = $skype->add_message_listener(\&mesasge_listener);
    $skype->remove_message_listener($listener);



=head1 COMMANDS WRAPPED

SkypeAPI wraps some of the skype commands  

=head2 SkypeAPI->get_command($WHAT, [$wait_times, $sleep_interval])

Send [GET WHAT COMMAND] to skype and wait for the response, then return the status

    my $status = $skype->get_command('userstatus');

=head2 SkypeAPI->get_message($message_id, $property, [$wait_times, $sleep_interval])

Send [GET CHATMESSAGE MESSAGEID PROPERTY] to skype and wait for the response, then return the property value

    my $body = $instance->get_message($message_id, 'body');

Available properties are: CHATNAME , TIMESTAMP , FROM_HANDLE , FROM_DISPNAME , TYPE , USERS , LEAVEREASON , BODY , STATUS. 
Refer to  L<https://developer.skype.com/Docs/ApiDoc/src#OBJECT_CHATMESSAGE>  for more detail. 

=head2 SkypeAPI->send_chat_message( $chat_id, $utf8_message, [$wait_times, $sleep_interval])

Send [CHATMESSAGE CHATID MESSAGE] to skype and wait for the response

    $skype->send_chat_message($chat_id, 'Hello');

=head2 SkypeAPI->search_chats($selector, [$wait_times, $sleep_interval])

Send [SEARCH SELECTOR MESSAGE] to skype and wait for the response, then return the ARRAYREF of the chats id

    my $ra_chats = $skype->search_chats('ACTIVECHATS');

Available selector are: CHATS , ACTIVECHATS , MISSEDCHATS, RECENTCHATS, BOOKMARKEDCHATS

=head1 DESCRIPTION

A Perl simple implementation of the Skype API, working off of the canonical Java and Python implementations.
It is a encapsulation of Windows message communication between Skype and client applications.
 This version of SkypeAPI only implement some commands of SKYPE API, you can implement the others using  SkypAPI->do_command or SkypAPI->do_command_for_result. 


=head2 EXPORT

None by default.

=head1 ROTBOT DEMO

You can find the robot.pl in the lib/../t/robot.pl, run it and your skype will become a xiaoi robot :)

the robot needs the module XiaoI, please install it first, See L<http://code.google.com/p/xiaoi/>


=head1 SEE ALSO

For more command information, See L<https://developer.skype.com/Docs/ApiDoc/src>

The svn source of this project, See L<http://code.google.com/p/skype4perl/>


=head1 AUTHOR

laomoi ( I<laomoi@gmail.com> )

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008 by laomoi

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itinstance, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.


=cut
