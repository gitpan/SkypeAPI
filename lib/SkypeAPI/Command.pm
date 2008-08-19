package SkypeAPI::Command;

use strict;
use warnings;

use Class::Accessor::Fast;
our @ISA = qw(Class::Accessor::Fast);

our $VERSION = '0.01';


# Preloaded methods go here.
use Time::HiRes qw( sleep );

__PACKAGE__->mk_accessors(
  qw/blocking id timeout string reply/
);


1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

SkypeAPI - Perl extension for blah blah blah

=head1 SYNOPSIS

  use SkypeAPI;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for SkypeAPI, created by h2xs. It looks like the
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
