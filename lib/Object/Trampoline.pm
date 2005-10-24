########################################################################
# Object::Trampoline
# delay construction of objects until they are needed.
########################################################################

package Object::Trampoline;

use strict;

use Carp;

our $AUTOLOAD = '';

AUTOLOAD
{
    my ( $ignore, $class, @argz ) = @_;

    my $name = ( split /::/, $AUTOLOAD )[ -1 ];

    croak "Bogus constructor call: '$class' cannot '$name'"
    unless $class->can( $name );

    bless 
    sub { $class->$name( @argz ) }, 
    'Object::Trampoline::Bounce'
}

package Object::Trampoline::Bounce;

use strict;

use Carp;

our $AUTOLOAD = '';

AUTOLOAD
{
    # replace the trampoline argument with the real
    # thing by calling its constructor -- call by 
    # reference is a Bery Good Thing.

    $_[0] = $_[0]->();

    my $class = ref $_[0];

    my $name = ( split /::/, $AUTOLOAD )[ -1 ];

    my $sub = $class->can( $name )
    or croak "Bogus method call: '$class' cannot '$name'";

    goto &$sub
}

DESTROY {}

# keep require happy
1

__END__

=head1 NAME

Object::Trampoline - delay object construction until a method 
is actually dispatched.

=head1 SYNOPSIS

    # the real class name is added to the normal constructor
    # and 'Object::Trampoline' used instead. in this case
    # the required object is in Expensive::Class and
    # has a constructor of "frobnicate".

    my $obj = Object::Trampoline->frobnicate( 'Expensive::Class', @args );

    # after that just use the object as-is and it'll
    # transform itself into whatever you asked for when
    # the first real method call is made using it.

    my $sth = $obj->foobar( @more_args );

    # specify the package and args from a config file or
    # via inherited data.

    my %config = Config->read( $config_file_path );

    my ( $class, $const, $argz )
    = @config{ qw( class const args ) };

    my $handle = Object::Trampoline->$const( $class, $argz );

    # at this point ref $handle eq 'Object::Trampoline::Bounce'

    $handle->do_something( @argz );

    # at this point ref $handle eq $class


=head1 DESCRIPTION

There are times when constructing an object is expensive
or has to be delayed -- heavily forked apache servers
are one example.  This module creates a "trampoline"
object: when called it replaces the object you have with
the object you want. The module itself consists only
of two AUTOLOADS: one with captures the constructor call,
the other the first method call. The first class blesses
a closure which creates the necessary object into the
second class, which replces $_[0] with a new object and
re-dispatches the call into the proper class.

Using an autoload as the constructor allows Object::Trampoline
to use whatever constructor name the "real" class uses
without having to pass it as another argument.

=head2 Delayed construction

Object::Trampoline uses whatever constructor the destination
class calls (e.g., 'connect' for DBI) with the destination class
is passed as the first argument.

For example:

    my $dbh = DBI->connect( 'dbi:Foo:', $user, $pass, $conf );

becomes

    my $dbh = Object::Trampoline( 'DBI', 'dbi:Foo:', $user, $pass, $conf );

    # at this point $dbh is an Object::Trampline

    my $sth = $dbh->prepare( 'select foo from bar' );

    # at this point $dbh is an DBI::db

This can be handy for error or other special event handlers
they are not always used -- especially if they have to read
initialization files or make database/directory service 
connections to get their setup data.

=head2 Runtime classes

This can also be handy for specifying a handler class 
via config or command-line arguments since the final
class is passed as an argument. If various handler 
classes share a constructor name then the first argument
to Object::Trampoline can be determined at runtime:

    my $mailclass = $cmdline->{ mailer } || 'SMTP::Simple';

    ...

    my $mailer = Object::Trampoline( $mailclass, @const_argz );

    ...

    # $mailclass construction is delayed up to this point.

    $mailer->send( %message );

This allows the actual class doing the deed to be set
at runtime via command line or config file. The same thing
can be done using "$mailclass->construct( @const_argz )"
but then the construction will not be delayed.

=head1 KNOWN BUGS

=over 4

=item

Not a bug, really, but if your constructor has side effects
(e.g., opening log files) then delaying the construction will
delay the side effects. Net result is that the side effects
should be moved into your import where feasable or you just
have to wait for the side effects to show up when the object
is really used.

=back

=head1 AUTHOR

Steven Lembark <lembark@wrkhors.com>

after which the first DBI call will convert $dbh from a 
Trampoline to a DBI handle.
