########################################################################
# Object::Trampoline
# delay construction of objects until they are needed.
########################################################################

package Object::Trampoline;

use strict;

our $VERSION = "0.04";

use Carp;

our $AUTOLOAD = '';

########################################################################
# the only purpose for this class is having an autoload
# that blesses things into O::T::Bounce.
#
# there may not be any arguments... either way i need
# to make a lexical copy of the stack for use in the
# closure.
#
# the closure delays actual contstruction until it is
# dereferenced in O::T::Bounce::AUTOLOAD.
#
# $sub is syntatic sugar but is inexpensive enough to
# construct.

AUTOLOAD
{
    # discard this class, then grab the "real" class
    # and its arguments and the constructor's name.

    shift;

    my $class = shift
    or croak "Bogus Object::Trampoline: missing destination class";

    my @argz = @_;

    my $name = ( split /::/, $AUTOLOAD )[ -1 ];

    my $sub = sub { $class->$name( @argz ) };

    bless $sub, 'Object::Trampoline::Bounce'
}

package Object::Trampoline::Bounce;

use strict;

*VERSION = \$Object::Trampoline::VERSION;

use Carp;

our $AUTOLOAD = '';

AUTOLOAD
{
    # replace the trampoline argument with the real
    # thing by calling its constructor -- call by 
    # reference is a Very Good Thing.

    $_[0] = $_[0]->();

    my $class = ref $_[0];

    my $name = ( split /::/, $AUTOLOAD )[ -1 ];

    # if the class implements te method directly
    # then goto is more effecient; otherwise use
    # the symbol table to dispatch it -- which 
    # will end up back here on the way through
    # the first time the method is called.

    if( my $sub = eval { $class->can( $name ) } )
    {
        goto &$sub
    }
    else
    {
        my $obj = shift;

        $obj->$name( @_ );

        # you'll end up here afater the call if
        # you're in the debugger stepping into
        # things...
    }
}

# stub destroy is necessary to dodge AUTOLOAD for
# unused objects.

DESTROY {}

# keep require happy

1

__END__

=head1 NAME

Object::Trampoline - delay object construction until
a method is actually dispatched, simplifies runtime definition
of handler classes.

=head1 SYNOPSIS

    # the real class name is added to the normal constructor
    # and 'Object::Trampoline' used instead. the destination
    # class' constructor is called when object is actually 
    # used for something.

    my $dbh = Object::Trampoline->connect( 'DBI', $dsn, $user, $pass, $conf );

    my $sth = $dbh->prepare( 'select foo from bar' );


    # or specify the package and args from a config file
    # or via inherited data.
    #
    # the constructor lives in the destination class
    # and has nothing to do with Object::Trampoline.

    my %config = Config->read( $config_file_path );

    my ( $class, $const, $argz )
    = @config{ qw( class const args ) };

    my $handle = Object::Trampoline->$const( $class, $argz );

    # at this point ref $handle is 'Object::Trampoline::Bounce'.

    $handle->frobnicate( @stuff );

    # at this point ref $handle is $class 

=head1 DESCRIPTION

There are times when constructing an object is expensive
or has to be delayed -- database handles in heavily forked
apache servers are one example.  This module creates
a "trampoline" object: when called it replaces the object
you have with the object you want. The module itself
consists only of two AUTOLOADS: one with captures the
constructor call, the other the first method call. The
first class blesses a closure which creates the necessary
object into the second class, which replces $_[0] with
a new object and re-dispatches the call into the proper
class.

Using an autoload as the constructor allows Object::Trampoline
to use whatever constructor name the "real" class uses
without having to pass it as another argument.

=head2 Delayed construction

Object::Trampoline uses whatever constructor the destination
class calls (e.g., 'connect' for DBI) with the destination class
is passed as the first argument.

For example the normal DBI construcion:

    my $dbh = DBI->connect( $dsn, $user, $pass, $conf );

becomes:

    my $dbh = Object::Trampoline->connect( 'DBI', $dsn, $user, $pass, $conf );

eventually follwed by some use of the $dbh:

    # at this point ref $dbh is "Object::Trampline::Bounce"

    my $sth = $dbh->prepare( 'select foo from bar' );

    # at this point ref $dbh is "DBI::db"

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
    my $mailconst = $cmdline->{ constuctor } || 'constructify';

    ...

    my $mailer = Object::Trampoline->$mailconst( $mailclass, @blah );

    ...

    # $mailclass construction is delayed up to this point.

    $mailer->send( %message );

This is useful when the constructor arguments themselvese
are expensive to arrive at but the handler object must be 
defined in advance. This allows $mailer to be defined 
even if the constructor arguments are not available (or
the construced class require-ed) yet.

Note that $mailconst has nothing to do with Object::Trampoline,
but must be accessble to a $mailclass object.

=head1 KNOWN BUGS

=over 4

=item

Not a bug, really, but if your constructor has side effects
(e.g., opening log files) then delaying the construction will
delay the side effects. Net result is that the side effects
should be moved into your import where feasable or you just
have to wait for the side effects to show up when the object
is really used.

=item 

Also not really a bug, but it is the caller's responsability
to actually "use" or "require" the destination class prior
to actually constructing the object.

=item

Another not-really-a-bug: if a trampoline object 
is initially shared via the symbol table then 
the $_[0] trick used here will create multiple 
instances of the object. In some cases this is
exactly what is required; in others (say an IRC
connection object that joins a chat) the multiple
objects instantiated will cause problems.

At the moment I'm trying to find a graceful way 
of replacing the object contents without knowing
the base data type, which may lead me into the 
dungeons of XS...  suggeions welcome :-)

=back

=head1 AUTHOR

Steven Lembark <lembark@wrkhors.com>

