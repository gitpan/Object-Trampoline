use ExtUtils::MakeMaker;

WriteMakefile
(
	NAME            => 'Object::Trampoline',
	VERSION         => '1.20',
	ABSTRACT_FROM   => './lib/Object/Trampoline.pm',

	PREREQ_PM =>
	{
        # take whatever versions are in the standard distro.

		strict    => 0,
		Carp      => 0,
	},

);
