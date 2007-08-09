#!/usr/bin/perl

use strict;
use warnings;

use File::Copy;
use File::Path;
use IO::Handle;

my @trees = qw(stable unstable);
my @oses  = qw(fc4 fc5 fc6 fc7 rhel3 rhel4 rhel5 suse9 suse10);

my $descriptions = {
	common => 'RPMs Common to All OpenNMS Architectures',
	fc4    => 'Fedora Core 4',
	fc5    => 'Fedora Core 5',
	fc6    => 'Fedora Core 6',
	fc7    => 'Fedora Core 7',
	rhel3  => 'RedHat Enterprise Linux 3.x and CentOS 3.x',
	rhel4  => 'RedHat Enterprise Linux 4.x and CentOS 4.x',
	rhel5  => 'RedHat Enterprise Linux 5.x and CentOS 5.x',
	suse9  => 'SuSE Linux 9.x',
	suse10 => 'SuSE Linux 10.x',
};

my $index = IO::Handle->new();
open($index, '>.index.html') or die "unable to write to index.html: $!";
print $index <<END;
<html>
 <head>
  <title>OpenNMS Yum Repository</title>
 </head>
 <body>
  <h1>OpenNMS Yum Repository</h1>
END

my @createrepo = qw(createrepo --verbose --pretty);

for my $tree (@trees) {
	my $title = ucfirst($tree);
	print $index "  <h2>$title</h2>\n";
	print $index "  <ul>\n";

	print $index "   <li>$descriptions->{'common'}</a> (<a href='$tree/common'>browse</a>)</li>\n";
	mkpath([$tree . '/common', 'caches/' . $tree . '/common', 'repofiles']);
	system(
		@createrepo,
		'--baseurl', "http://yum.opennms.org/$tree/common",
		'--outputdir', "$tree/common",
		'--cachedir', "../../caches/$tree/common",
		"$tree/common"
	) == 0 or die "unable to run createrepo: $!";

	write_repofile($tree, 'common', $descriptions->{'common'});

	for my $os (@oses) {
		print $index "   <li><a href='$tree/$os/opennms/opennms-repo.rpm'>$descriptions->{$os}</a> (<a href='$tree/$os'>browse</a>)</li>\n";

		mkpath([$tree . '/' . $os, 'caches/' . $tree . '/' . $os, 'repofiles']);
		write_repofile($tree, $os, $descriptions->{$os});
		make_rpm($tree, $os);

		system(
			@createrepo,
			'--baseurl', "http://yum.opennms.org/$tree/$os",
			'--outputdir', "$tree/$os",
			'--cachedir', "../../caches/$tree/$os",
			"$tree/$os",
		) == 0 or die "unable to run createrepo: $!";
	}
	print $index "  </ul>\n";
}

print $index <<END;
 </body>
</html>
END

close ($index);

move('.index.html', 'index.html');

sub write_repofile {
	my $tree        = shift;
	my $os          = shift;
	my $description = shift;

	my $repofile = IO::Handle->new();
	open($repofile, ">repofiles/opennms-$tree-$os.repo") or die "unable to write to repofiles/opennms-$tree-$os.repo: $!";
	print $repofile <<END;
[opennms-$tree-$os]
name=$description RPMs ($tree)
baseurl=http://yum.opennms.org/$tree/$os
mirrorlist=http://yum.opennms.org/mirrorlists/$tree-$os.txt
failovermethod=priority
gpgcheck=1
gpgkey=http://yum.opennms.org/OPENNMS-GPG-KEY
END
	close($repofile);

	if (not -f "mirrorlists/$tree-$os.txt") {
		my $mirrorlist = IO::Handle->new();
		open ($mirrorlist, ">mirrorlists/$tree-$os.txt") or die "unable to write to mirrorlists/$tree-$os.txt: $!";
		print $mirrorlist "http://yum.opennms.org/$tree/$os\n";
		close ($mirrorlist);
	}
}

sub make_rpm {
	my $tree = shift;
	my $os   = shift;

	for my $dir ('tmp', 'SPECS', 'SOURCES', 'RPMS', 'SRPMS', 'BUILD') {
		mkpath(['/tmp/rpm-repo/' . $dir]);
	}
	copy("repofiles/opennms-$tree-$os.repo",    "/tmp/rpm-repo/SOURCES/");
	copy("repofiles/opennms-$tree-common.repo", "/tmp/rpm-repo/SOURCES/");

	my @command = (
		"rpmbuild", "-bb",
		"--buildroot=/tmp/rpm-repo/tmp/buildroot",
		"--define", "_topdir /tmp/rpm-repo",
		"--define", "_tree $tree",
		"--define", "_osname $os",
		"repo.spec"
	);
	print "running @command\n";
	system(@command) == 0 or die "unable to build rpm: $!";

	if (opendir(DIR, "/tmp/rpm-repo/RPMS/noarch")) {
		my @files;
		for my $file (readdir(DIR)) {
			chomp($file);
			if ($file =~ /\.rpm$/) {
				push(@files, "/tmp/rpm-repo/RPMS/noarch/$file");
			}
		}
		closedir(DIR);
		for my $file (@files) {
			mkpath(["$tree/$os/opennms"]);
			move($file, "$tree/$os/opennms/");
		}
	}
}
