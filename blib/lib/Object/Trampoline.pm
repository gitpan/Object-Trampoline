########################################################################
# Object::Trampoline
# delay construction of objects until they are needed.
########################################################################

package Object::Trampoline;

use strict;

our $VERSION = "0.03";

use Carp;

our $AUTOLOAD = '';

AUTOLOAD
{
    # this class is meaningless, since the object
    # will always be blessed into O::T::Bounce
    # anyway. the call that got us here is useful
    # since it is the destination class' const.
    #
    # $sub is syntatic sugar but is inexpensive
    # enough to construct.

    my ( $ignore, $class, @argz ) = @_;

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

    my $sub = eval { $class->can( $name ) }
    or croak "Bogus method call: '$class' cannot '$name': $@";

    goto &$sub
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


At this point anyonen can use Our::Channel::Catalog
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

=head1 KNOWN BUGS

=over 4

=item

Not a bug, really, but if your constructor has side effects
(e.g., opening log files) then delaying the construction will
delay the side effects. Net result is that the side effects
may have to migrate into the import where feasable or you just
have to wait for the side effects to show up when the object
is really used.

=item 

Also not really a bug, but it is the caller's responsability
to actually "use" or "require" the destination class prior
to actually constructing the object. The simple cases could
be handled with a string eval, but then there isn't a good
way to determine if a require or use is the proper choice.
In the interest of simplicity I've left that to the caller.

=over 4

One way around this would be passing in a closure as the 
first argument instead of the class. This could be executed
as-is to get the object. If anyone has a strong opinion on
this please warn me.

=back

=back

=head1 AUTHOR

Steven Lembark <lembark@wrkhors.com>

