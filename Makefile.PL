use strict;
use vars qw{$VERSION};
BEGIN {
	require 5.003_96;
	$VERSION = '0.01';
}
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Stiki',
    VERSION           => $VERSION
	PREREQ_PM => {
		# Skip on Windows to avoid breaking ActivePerl PPMs
		# 0.47 means 5.6.2 or newer, which everyone on Win32 has.
		($^O eq 'MSWin32' ? () : ('Test::More' => '0.47')),
	},
	($] >= 5.005 ? (
		AUTHOR  => 'Bernie Simon <bernie.simon@gmail.com>',
	) : ()),
	($ExtUtils::MakeMaker::VERSION ge '6.30_00' ? (
		LICENSE => 'perl',
	) : ()),
);
