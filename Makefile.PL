use ExtUtils::MakeMaker;

WriteMakefile
(
	NAME            => 'Object::Trampoline',
	VERSION         => '0.01',
	ABSTRACT		=> <<'END',
Delay construction of objects until their methods are 
actually called. The destination objects's constructor
is used, with Object::Trampoline as the class and an
additinal leading argument of the destination class.
END

	PREREQ_PM =>
	{
        # take whatever versions are in the standard distro.

		strict    => 0,
		Carp      => 0,
	},

);
