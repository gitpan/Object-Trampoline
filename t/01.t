use Test::More ( tests => 13 );

use_ok( 'Object::Trampoline' );

my $abc = Object::Trampoline->frobnicate( 'abc', foo => 'bar' );
my $ijk = Object::Trampoline->frobnicate( 'ijk', foo => 'bar' );
my $xyz = Object::Trampoline->frobnicate( 'xyz', foo => 'bar' );

is( ref $abc, 'Object::Trampoline::Bounce', 'abc is a tramploline object' );
is( ref $ijk, 'Object::Trampoline::Bounce', 'ijk is a tramploline object' );
is( ref $xyz, 'Object::Trampoline::Bounce', 'xyz is a tramploline object' );

# this should convert the objects to their
# destination classes.

my $abc_foo = $abc->foo;
my $ijk_foo = $ijk->foo;
my $xyz_foo = $xyz->foo;

is( ref $abc, 'abc', 'abc is now an abc' );
is( ref $ijk, 'ijk', 'ijk is now an ijk' );
is( ref $xyz, 'xyz', 'xyz is now an xyz' );

ok( $abc->{foo}     eq 'bar', 'abc is a hashref'    );
ok( $ijk->[1]       eq 'bar', 'ijk is an arrayref'  );
ok( ( $xyz->() )[1] eq 'bar', 'xyz is a subref'     );

ok( $abc_foo eq 'abc', 'abc calls the correct foo' );
ok( $ijk_foo eq 'ijk', 'ijk calls the correct foo' );
ok( $xyz_foo eq 'xyz', 'xyz calls the correct foo' );

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


    sub foo { __PACKAGE__ }


    package xyz;

    sub frobnicate
    {
        my $proto = shift;

        my @a = @_;
        
        bless sub{ @a }, $proto
    }


    sub foo { __PACKAGE__ };
}

__END__
