use strict;
use FindBin qw/$Bin/;
use lib '$Bin/../lib';
use SkypeAPI;
use Data::Dumper;

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
    
    my $achats = $skype->search_chats('ACTIVECHATS');
    print Dumper($achats), "\n";
    
    my $chats = $skype->search_chats('chats');
    print Dumper($chats), "\n";
    
    my $missedchats = $skype->search_chats('MISSEDCHATS');
    print Dumper($missedchats), "\n";
    
    my $RECENTCHATS = $skype->search_chats('RECENTCHATS');
    print Dumper($RECENTCHATS), "\n";
    
    my $BOOKMARKEDCHATS = $skype->search_chats('BOOKMARKEDCHATS');
    print Dumper($BOOKMARKEDCHATS), "\n";
    
    
    #send message to recenly chat
    if (@$RECENTCHATS > 0) {
        $skype->send_chat_message($RECENTCHATS->[0], '您好,我是帅哥');
    }
   
    my $i1 = $skype->add_message_listener(\&mesasge_listener, 1);
    $skype->message_listen();
    



sub mesasge_listener {
    my ($instance, $message_id) = @_;
    
    print "I received message $message_id\n";
     my $CHATNAME  = $instance->get_message($message_id, 'CHATNAME');
    print "CHATNAME :$CHATNAME \n";
    
    my $body = $instance->get_message($message_id, 'body');
    print "body:$body\n";
    
    return 1;
}


__END__
    my $skype = SkypeAPI->new({is_verbose => 1});
    
    while (my $line = <STDIN>) {
        chomp($line);
        $skype->do_command($line);
        sleep 1;
    }
    
__END__
    my $skype = SkypeAPI->new({is_verbose => 1});
    sleep 5;
    while (my $line = <STDIN>) {
        chomp($line);

        my $cmd_id = $skype->do_command_for_result($line);
        for (1..100) {
            my $result = $skype->pop_command_result($cmd_id);
            print "[$cmd_id]$result", "\n";
            if ($result ne '-1' and $result ne '-2') {
                last;
            }
            sleep 0.1;
        }
        
    }    
    
__END__
    while (my $line = <STDIN>) {
        chomp($line);

        my $cmd_id = $skype->do_command_for_result($line);
        print "$cmd_id=>\n";
        my $result = $skype->wait_message($cmd_id);
        print "$result", "\n";        
    }      