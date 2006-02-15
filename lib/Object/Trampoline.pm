########################################################################
# Object::Trampoline
# delay construction of objects until they are needed.
#
# the only purpose for the top two classes is having an autoload
# that blesses things into O::T::Bounce.
########################################################################

package Object::Trampoline;

use strict;

use Carp;

########################################################################
# package variables
########################################################################

our $VERSION = "1.25";

########################################################################
#
# start by grabbing the destination class and its arguments
# off the stack.  the constructor name is whatever is
# being autoloaded.
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
#
# Note: there are no DESTROY blocks in the constructing
# classes since no objects ever live there: they begin
# life in O::T::Bounce.
#
# catch: some classes use tied items to encapsulate their
# configuration attributes (e.g., DBI). this leaves the 
# first access sometimes in a tied operation... the object
# passed to a tie operator is >>NOT<< the wrapped operator.
# this requires a lookup table of tied guts to wrappers.

our $AUTOLOAD = '';

AUTOLOAD
{
    # discard this class name

    shift;

    my ( $class, @argz ) = @_
    or croak "Bogus Object::Trampoline: missing destination class";

    my $const = ( split /::/, $AUTOLOAD )[ -1 ];

    # the construction is delayed until this gets called.

    bless sub { $class->$const( @argz ) },
    'Object::Trampoline::Bounce'
}

########################################################################
# same gizmo as O::T except that the class is use-ed before the 
# constructor is called. 

package Object::Trampoline::Use;

use strict;

use Carp;

*VERSION = \$Object::Trampoline::VERSION;

our $AUTOLOAD = '';

AUTOLOAD
{
    # this version does slightly more work since it 
    # has to put using the module into the caller's
    # class before calling the constructor.

    shift;

    # grab the destination class and its arguments off the stack.
    # the constructor name is whatever is being autoloaded.

    my ( $class, @argz ) = @_
    or croak "Bogus Object::Trampoline: missing destination class";

    my $const = ( split /::/, $AUTOLOAD )[ -1 ];

    my $caller = caller;

    my $sub
    = sub
    {
        eval
        qq{
            package $caller;
            use $class;
        };
        
        $class->$const( @argz )
    };

    bless $sub, 'Object::Trampoline::Bounce'
}

########################################################################
# where the object ends up. All this does is possibly use the package
# then construct the object and dispatch the call to whatever the 
# caller was looking for -- which may fail if the package doesn't
# implement the method.
#
# the syntax here gets a bit hairy since the blessed object is
# not being updated, the referent it contains is. replacing the
# anon sub allows re-executing it without creating a new object.
#
# there is also a reference counting issue here since the anon
# sub maintained by $_[0] has a reference to the trampolined
# object. this is survivable, however, since $_[0] is overwritten
# by the object itself. this kills the stub subref at the exit
# of AUTOLOAD unless there are other copies of the original
# trampoline object keeping it alive. 
#
# note that it's up to the caller to deal with any exceptions
# that come out of calling the method.
#
# goto is a more effecient way to get there if the class
# has an explicit method for handling the call; otherwise
# use the name to dispatch the call.

package Object::Trampoline::Bounce;

use strict;

use Carp;

*VERSION = \$Object::Trampoline::VERSION;

our $AUTOLOAD = '';

AUTOLOAD
{

    my $obj = $_[0] = $_[0]->();

    my $class = ref $obj;

    my $name = ( split /::/, $AUTOLOAD )[ -1 ];

    # the caller is left to deal with any problems calling
    # the constructor. can might fail if the constructor
    # is autoloaded or an AUTOLOAD of its own (e.g., 
    # Obj::Autostub).

    if( my $sub = $obj->can( $name ) )
    {
        goto &$sub;
    }
    else
    {
        shift;

        $obj->$name( @_ )
    }
}

# stub destroy dodges AUTOLOAD for unused trampolines.

DESTROY {}

# keep require happy

1

__END__

=head1 NAME

Object::Trampoline - delay object construction, and optinally
using the class' module, until a method is actually dispatched,
simplifies runtime definition of handler classes.

=head1 SYNOPSIS

    # adding "use_class" will perform an "eval use $class"
    # at the point where the object is first accessed.

    use Object::Trampoline;

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

    my ( $class, $const, @argz )
    = @config{ qw( class const args ) };

    my $handle = Object::Trampoline->$const( $class, @argz );

    # at this point ref $handle is 'Object::Trampoline::Bounce'.

    $handle->frobnicate( @stuff );

    # at this point ref $handle is $class 

    # there are times when it is helpful to delay using
    # the object's class module until the object is 
    # instantiated. O::T::U adds the caller's package
    # and a "use $class" before the constructor.

    my $lazy = Object::Trampoline::Use->frobnicate( $class, @stuff );

    my $result = $lazy->susan( 'dessert' );


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
    my $mailconst = $cmdline->{ constructor } || 'constructify';

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

=head2 Handle Catalogs

There are times when centeralizing the construction of a
few standard handles into a single module seems helpful:
all of the configuration issues can be pushed into a single
place and anyone who uses the module can get access to some
set of standard resources. The obvious downside to this is
having to construct all of the objects.

Trampoline objects overcome this by not constructing anything
[expensive] until it is really kneaded. Thus, a single 
"channel catalog" can be pushed into a single module (or
small set of them). 

A hard-coded catalog might start out as:
    
    
    package Our::Channel::Catalog;

    use Our::Cmdline::Handler;

    my %defaultz =
    (
        test_host => 'testify.mysubnet',
        test_user => 'ttocs',
        test_pass => 'regit',
        test_data => 'foo',

        ...
    );

    my $cmdline = Our::Cmdline::Handler->construct( %defaultz );

    ...

    my $handlz = 
    {
        test_db =>
        Object::Catalog->connect
        (
            DBI =>
            (
                'dbi:mysql:hostname=$cmdline->{test_host};database=$cmdline->{test_data}',
                $cmdline->{user},
                $cmdline->{pass},
                $db_config,
            ),
        ),

        prod_db =>
        Object::Catalog->connect
        (
            DBI =>
            (
                'dbi:mysql:hostname=$cmdline->{test_host};database=$cmdline->{test_data}',
                $cmdline->{user},
                $cmdline->{pass},
                $db_config,
            ),
        ),

        test_chat =>
        Object::Catalog->connect
        (
            'Foo::Bar::Chatter' =>
            (
                Host => $cmdline->{chat_host},
                User => $cmdline->{chat_user},
                Pass => $cmdline->{chat_pass},
                Port => $cmdline->{chat_port},
            ),
        ),

        test_ldap =>
        ...

    };

    sub import
    {
        use Symbol;

        my $caller = caller;

        my $ref = qualify_to_ref 'handlz', $caller;

        *$ref = $handlz;
    }


At this point anyone can use Our::Channel::Catalog
and have immeidate access to the standard handles
(which have their default values and list pushed into
the revision control system).

A more realistic use of this puts the construction
parameters into, say, LDAP (e.g., RH Directory) for
shared use. The module can then isolate all the 
configuration issues into one place. 

Combined with FindBin::libs and NEXT::init a group
can inherit the necessary channels into a local 
catalog that varies by project or module. One way
to handle this is a collection of default channel
modules that are collected together via use base 
and NEXT::init into project-specific blocks of 
handles. This gives projects the flexability to 
generate a stock set of available handles without
the overhead of fully instantiating them all for 
each piece of code that uses any of them.

=head2 Debugging with restricted resources.

There are times when objects must bind ports, access
unique-login services, or otherwise compete from single-
use resources. Trampoline objects can help here: by 
delaying the resource use until something is actually
done with the object they allow debugging of startup 
issues. Obviously at some point there may be a resource
collision, but at least this delays things until the
last possible time.

=head2 Avoiding "circular use" situations

When multiple layers of inheritence are used to build 
up the metadata for an object there are times when 
the layering gets complicated. It may be that all of
the data is where it needs to be by the time objects
are created, but the "use" pragma is in an implicit
BEGIN block, which can cause startup errors.

Object::Trampoline::Use delays using the constructing
class until the object is actually used. This allows
any configuration to be handled in time, even if some
of the configuration involves objects from the included
classes.

Say that a project's Defaults.pm reads the command
line and folds in static default values. After that
Channels.pm creates various channel object using
the configuration values. Another overall configuration
module might then use the Defaults and Channels to
get its list of exported values.

Problems start when modules implementing the channels 
use values from the configuration module, leading 
to a circular use situation at startup.

Object::Trampoline::Use avoids this issue by allowing
the channel objects to be configured in lower-level
modules, with their class import and instantiation 
delayed until the objects are used. The configuration
module can merrily hand out channel objects, who'se 
classes will not be use-ed until after the configuration
stack is complete.

=head1 SEE ALSO

=over 4

=item As always perldoc is your friend...

All of these have useful information in them:

    perlref

    perlreftut

    perltie

=item _OO Perl_, Damian Conway

Lots of examples, goes over how to deal with constructing
tied objects.

=back

=head1 KNOWN ISSUES

=head2 Delaying construction

=over 4

=item Constructor external side effects

If your constructor has side effects (e.g., opening log
files) then delaying the construction will delay the
side effects. Net result is that the side effects may
have to migrate into the import where feasable or you
just have to wait for the side effects to show up when
the object is really used.

=item Constructor modifying @_

If your code depends on side-effects of the constructor
manipulating the values in @_ then this module will not
work for you: the call stack is copied to a lexical in 
order to create the constructor closure. This will not
be a problem for any module I know of.

=item Late "use" 

Object::Trampoline::Use will use the module in the 
caller's package, but the use will be delayed until
an object is use-ed. This will delay side effects of
import calls. Even if this does not cause errors, 
calling Foo->import() can lead to startup messages
or delayed errors. 

If this is a problem then use the module in the main
code with Object::Trampoline to create it.  This puts
the onus of use, require, or do of the module defining
the class onto the caller.

=back

=head2 Other design issues (Caveat Saltor)

=over 4

=item Passing arguments to import

There is no way to pass arguments to the use call for
a class in Object::Trampoline::Use. If that is necessary
then either use the class with Object::Trampoline or 
write a wrapper class whose constructor uses the class
with the appropriate arguments.

=item Tied objects

Depending on how your class is constructed, the tied
operators may not be available in the same class as
the object's class (which actually makes life easier
in Perl). Trick is that until the object has a method
called on it the constructor never has a chance to tie
the thing, so tied access breaks.

Another way to look at it is that a Trampoline object 
won't be tied to whatever the real class uses.

There isn't any way I've found yet to create a generic
tie class: one with an autoload that will gracefully
handle scalar, array, hash, and file operations in a
way that I can pass through AUTOLOAD to instantiate the
object. Every fix I've seen so far requires knowing the
base type of the object beforehand.

Suggestions welcome.


=item Operator overloading

Ditto the overloads: until the thing is really blessed
into the appropriate class there isn't any way to 
associate the operators with it. 

Simple fix is to call a 'sub' method to ricochet off
the AUTOLOAD before using the overloads.


=item Sharing objects

Object::Trampoline will create a single instance of the
object. This is usually just what you want: a single
database or network connection handle with delayed 
construction. 

Creating copies of the trampoline object itself, however,
can generate multiple copies of the bounced object. Which
is normally just what you want.

There are some pathalogical cases where arguments are 
copied into lexical variables and then called that the 
original trampoline will create copies -- essentially 
acting as a factory. If you see more construction and
destruction than planned, check how the trampolines
are passed around and you'll probably find a lexical 
copy somewhere that is popluating itself instead of the
global copy. The fix there is to install the trampoline
into the caller's space (e.g., using Symbol) or use it
via $_[X] instead of copying the thing.

See ./t/03.t for examples of how a single trampoline object
can be installed for sharing in multiple packages.

=back

=head1 KNOWN BUGS

None, yet...

=head1 AUTHOR

Steven Lembark <lembark@wrkhors.com>

