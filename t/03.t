
use strict;
use lib qw( t );

use Object::Trampoline;

use Symbol      qw( qualify_to_ref );
use Test::More  qw( tests 22 );

my $ref = qualify_to_ref 'Carp::croak';

undef &{ *$ref };

my $found   = '';
my $expect  = '';

*$ref
= sub
{
    my $found    = shift;

    ok ! ( index $found, $expect ), "Found '$expect' ($found)";

    # break out of the AUTOLOAD.

    die "Test\n"
};

# found false names?

$expect = q{Object::Trampoline: class is false.};
eval { Object::Trampoline->frobnicate( '' ) };
ok $@ eq "Test\n", 'Test croak called';

$expect = q{Object::Trampoline: class is false.};
eval { Object::Trampoline::Use->frobnicate( '' ) };
ok $@ eq "Test\n", 'Test croak called';

$expect = q{Object::Trampoline: class is false.};
eval { Object::Trampoline->frobnicate( undef ) };
ok $@ eq "Test\n", 'Test croak called';

$expect = q{Object::Trampoline: class is false.};
eval { Object::Trampoline::Use->frobnicate( undef ) };
ok $@ eq "Test\n", 'Test croak called';

$expect = q{Object::Trampoline: class is false.};
eval { Object::Trampoline->frobnicate() };
ok $@ eq "Test\n", 'Test croak called';

$expect = q{Object::Trampoline: class is false.};
eval { Object::Trampoline::Use->frobnicate() };
ok $@ eq "Test\n", 'Test croak called';

# found bogus names (not valid packages):

$expect = q{Bogus Object::Trampoline: '1234' is invalid classname.};
eval { Object::Trampoline->frobnicate( '1234' ) };
ok $@ eq "Test\n", 'Test croak called';

$expect = q{Bogus Object::Trampoline: 'ab%cd' is invalid classname.};
eval { Object::Trampoline->frobnicate( 'ab%cd' ) };
ok $@ eq "Test\n", 'Test croak called';

$expect = q{Bogus Object::Trampoline: '1234' is invalid classname.};
eval { Object::Trampoline::Use->frobnicate( '1234' ) };
ok $@ eq "Test\n", 'Test croak called';

$expect = q{Bogus Object::Trampoline: 'ab%cd' is invalid classname.};
eval { Object::Trampoline::Use->frobnicate( 'ab%cd' ) };
ok $@ eq "Test\n", 'Test croak called';

# failed to load package with zero exit?

$expect     = q{Failed:};
my $tramp   = Object::Trampoline::Use->frobnicate( 'Broken' );

eval { $tramp->breaks_here };
ok $@ eq "Test\n", 'Test croak called';

__END__
