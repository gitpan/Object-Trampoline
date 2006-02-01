
# sanity check: will three objects created with different
# types in different packages get assigned the proper data
# types in the correct packages.

use Object::Trampoline;

use Test::More ( tests => 12 );

# create three trampolines. note that "frobnicate" is the
# constructor for each of them.

my $abc = Object::Trampoline->frobnicate( 'abc', foo => 'bar' );
my $ijk = Object::Trampoline->frobnicate( 'ijk', foo => 'bar' );
my $xyz = Object::Trampoline->frobnicate( 'xyz', foo => 'bar' );

# at this point all three objects are blessed into O::T::Bounce.

is( ref $abc, 'Object::Trampoline::Bounce', 'abc is a trampoline object' );
is( ref $ijk, 'Object::Trampoline::Bounce', 'ijk is a trampoline object' );
is( ref $xyz, 'Object::Trampoline::Bounce', 'xyz is a trampoline object' );

# at this point a method is called using the 
# objects. this converts them from O::T::B
# into whatever would've been constructed 
# in the first place by the original calls
# to the constructor ("frobnicate").

my $abc_value = $abc->foo;
my $ijk_value = $ijk->bar;
my $xyz_value = $xyz->baz;

# at this point all three objects should be 
# blessed into their respective classes.
#
# two sanity checks: the ref's have changed
# and they each have different data structures.

is( ref $abc, 'abc', 'abc is now an abc' );
is( ref $ijk, 'ijk', 'ijk is now an ijk' );
is( ref $xyz, 'xyz', 'xyz is now an xyz' );

ok( $abc->{foo}     eq 'bar', 'abc is a hashref'    );
ok( $ijk->[1]       eq 'bar', 'ijk is an arrayref'  );
ok( ( $xyz->() )[1] eq 'bar', 'xyz is a subref'     );

ok( $abc_value eq 'abc', 'abc calls the correct foo' );
ok( $ijk_value eq 'ijk', 'ijk calls the correct foo' );
ok( $xyz_value eq 'xyz', 'xyz calls the correct foo' );

{
    package abc;

    sub frobnicate
    {
        my $proto = shift;
        
        bless { @_ }, $proto
    }

    sub foo { __PACKAGE__ }


    package ijk;

    sub frobnicate
    {
        my $proto = shift;
        
        bless [ @_ ], $proto
    }


    sub bar { __PACKAGE__ }


    package xyz;

    sub frobnicate
    {
        my $proto = shift;

        my @a = @_;
        
        bless sub{ @a }, $proto
    }


    sub baz { __PACKAGE__ };
}

__END__
