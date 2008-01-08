#!/usr/bin/perl -w

use File::Path;
use strict;
use warnings;

my @sfmirrors = qw(
	http://us.dl.sourceforge.net/sourceforge/opennms
	http://easynews.dl.sourceforge.net/sourceforge/opennms
	http://internap.dl.sourceforge.net/sourceforge/opennms
	http://superb-west.dl.sourceforge.net/sourceforge/opennms
	http://superb-east.dl.sourceforge.net/sourceforge/opennms
	http://umn.dl.sourceforge.net/sourceforge/opennms
	http://jaist.dl.sourceforge.net/sourceforge/opennms
	http://nchc.dl.sourceforge.net/sourceforge/opennms
	http://optusnet.dl.sourceforge.net/sourceforge/opennms
	http://eu.dl.sourceforge.net/sourceforge/opennms
	http://belnet.dl.sourceforge.net/sourceforge/opennms
	http://puzzle.dl.sourceforge.net/sourceforge/opennms
	http://switch.dl.sourceforge.net/sourceforge/opennms
	http://mesh.dl.sourceforge.net/sourceforge/opennms
	http://heanet.dl.sourceforge.net/sourceforge/opennms
	http://surfnet.dl.sourceforge.net/sourceforge/opennms
	http://kent.dl.sourceforge.net/sourceforge/opennms
	http://ufpr.dl.sourceforge.net/sourceforge/opennms
);

open (FILE, "find . ! -type d |") or die "can't run find: $!\n";
while (my $file = <FILE>) {
	chomp($file);
	$file =~ s/^\.\///;
	next unless ($file =~ /\.rpm$/);
	next if ($file =~ /^flat\//);
	next if ($file =~ /repofile/);
	next if ($file =~ /\/snapshot\//);

	my ($tree, $os, $filename);
	my (@entries) = split(/\//, $file);
	if (@entries == 5) {
		($tree, $os, undef, undef, $filename) = split(/\//, $file);
	} elsif (@entries == 4) {
		($tree, $os, undef, $filename) = split(/\//, $file);
	} elsif (@entries == 3) {
		($tree, $os, $filename) = split(/\//, $file);
	}

	if (not $filename) {
		die "uninitialized filename : $file\n";
	}

	my ($packagename, $arch) = $filename =~ m/^(.*)[\-\.]([^\-\.]+)\.rpm/;
	$packagename =~ s/\_?${os}//;
	$packagename .= '.' . $os unless ($packagename =~ /^opennms-/);

	if (not $tree or not $filename) {
		die "don't know what to do with $file (tree = $tree, filename = $filename)\n";
	}

	mkpath("flat/$tree/$os");
	symlink("../../../$file", "flat/$tree/$os/$packagename.$arch.rpm");

	open (FILEOUT, ">flat/$tree/$os/mirrorlist.txt") or die "can't write to mirrorlist for $tree/$os: $!";
	for my $mirror (@sfmirrors) {
		print FILEOUT $mirror, "\n";
	}
	close (FILEOUT);
}
close (FILE);
