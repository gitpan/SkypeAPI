package SkypeAPI::Win;

use 5.008005;
use strict;
use warnings;

require Exporter;
use Class::Accessor::Fast;

our @ISA = qw(Exporter Class::Accessor::Fast);

our $VERSION = '0.01';

require XSLoader;
XSLoader::load('SkypeAPI::Win', $VERSION);

# Preloaded methods go here.
use threads;
use threads::shared;
use Data::Dumper;

__PACKAGE__->mk_accessors(
  qw/thread   is_running/
);


sub init {
    my $self = shift;
    my $handler_list = shift;
    my $thread = new threads(\&run, $self, $handler_list);
    $self->thread($thread);
}

sub run {
    my $self = shift;
    $self->attach( { copy_data => \&handler } );
}

sub handler {
    my $message = shift;
    print "[api]$message\n";
    if (defined $message and $message =~ m{^#(\w+)\s+(.*)}) {
        my ($id, $reply) = ($1, $2);
        if ($SkypeAPI::command_list{$id}) {
            my $command;
            {
                lock %SkypeAPI::command_list;
                $command = delete $SkypeAPI::command_list{$id};
                
            }
            
            {
                lock $SkypeAPI::command_lock;
                
                $command->reply($reply); 
               
            }
            
        }  
    } else {
        lock @SkypeAPI::message_list;
        push @SkypeAPI::message_list, $message;
    }

    #print Dumper(\%SkypeAPI::command_list);
}



sub DESTROY {
    my $self = shift;
    if ($self->thread) {
        $self->quit();
        $self->thread->join;
        $self->thread(undef);
    }
}




1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

SkypeAPI::Win - Perl extension for blah blah blah

=head1 SYNOPSIS

  use SkypeAPI::Win;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for SkypeAPI::Win, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

A. U. Thor, E<lt>a.u.thor@a.galaxy.far.far.awayE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008 by A. U. Thor

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.


=cut
