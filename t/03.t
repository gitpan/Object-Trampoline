
# slightly more complicated: will the same object installed
# by assigning to a glob end up as the same object?

use strict;

use Symbol;

use Object::Trampoline;

use Test::More qw( no_plan );

my $class = 'whatsis';

{
    my $t = Object::Trampoline->construct( $class );

    for( qw( abc ijk xyz ) )
    {
        my $ref = qualify_to_ref 't', $_;

        *$ref = \$t;
    }
}

isa_ok( $abc::t,    'Object::Trampoline::Bounce' );
isa_ok( $ijk::t,    'Object::Trampoline::Bounce' );
isa_ok( $xyz::t,    'Object::Trampoline::Bounce' );

# calling frobnicate on any one of them updates them all:
# the type changes and the value is modified.

print "\nFrobnicating abc...\n";

$abc::t->frobnicate;

isa_ok( $abc::t,    $class );
isa_ok( $ijk::t,    $class );
isa_ok( $xyz::t,    $class );

ok( $$abc::t == $$ijk::t, 'abc == ijk' );
ok( $$abc::t == $$xyz::t, 'abc == xyz' );

# updating any one of these should update all of them.

for
(
    [ $abc::t, 'foo' ],
    [ $ijk::t, 'bar' ],
    [ $xyz::t, 'xxx' ],
)
{
    my( $obj, $value ) = @$_;

    $$obj = $value;

    ok( $$abc::t eq $value, "abc updated to $value" );
    ok( $$ijk::t eq $value, "ijk updated to $value" );
    ok( $$xyz::t eq $value, "xyz updated to $value" );
}

# at this point if nothing has failed then the three
# instances $XXX::t are the "same" variable created
# via the trampoline.

package whatsis;

use strict;
use Scalar::Util qw( refaddr );

sub construct   { bless \( my $a = '' ), __PACKAGE__ }

sub frobnicate  { ${ $_[0] } = refaddr $_[0] }

# this isn't a module

0

__END__
