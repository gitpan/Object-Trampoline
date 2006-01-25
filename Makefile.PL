use ExtUtils::MakeMaker;

WriteMakefile
(
	NAME            => 'Object::Trampoline',
	VERSION         => '1.12',
	ABSTRACT		=> <<'TEXT',
Delay construction of objects until their methods are 
actually called with minimal source code interference.
Optionally use-es the constructing class in the block
where the construcor is called.
TEXT

	PREREQ_PM =>
	{
        # take whatever versions are in the standard distro.

		strict    => 0,
		Carp      => 0,
	},

);
