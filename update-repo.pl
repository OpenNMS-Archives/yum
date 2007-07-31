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

for my $tree (@trees) {
	my $title = ucfirst($tree);
	print $index "  <h2>$title</h2>\n";
	print $index "  <ul>\n";

	for my $dir ('common', @oses) {
		print $index "   <li><a href='repofiles/opennms-$tree-$dir.repo'>$descriptions->{$dir}</a> (<a href='$tree/$dir'>browse</a>)</li>\n";

		mkpath([$tree . '/' . $dir, 'caches/' . $tree . '/' . $dir, 'repofiles']);
		#system('chown', '-R', 'root:root', "$tree/$dir", "caches/$tree/$dir") == 0 or die "unable to chown $tree/$dir and caches/$tree/$dir: $!";
		system(
			'createrepo',
			'--baseurl', "http://yum.opennms.org/$tree/$dir",
			'--outputdir', "$tree/$dir",
			'--verbose',
			'--cachedir', "../../caches/$tree/$dir",
			'--pretty',
			"$tree/$dir",
		) == 0 or die "unable to run createrepo: $!";

		my $repofile = IO::Handle->new();
		open($repofile, ">repofiles/opennms-$tree-$dir.repo") or die "unable to write to repofiles/opennms-$tree-$dir.repo: $!";
		print $repofile <<END;
[opennms-$tree-$dir]
name=$descriptions->{$dir} RPMs ($tree)
baseurl=http://yum.opennms.org/$tree/$dir
mirrorlist=http://yum.opennms.org/mirrorlists/$tree-$dir.txt
failovermethod=priority
gpgcheck=1
gpgkey=http://yum.opennms.org/OPENNMS-GPG-KEY
END
		close($repofile);

		if (not -f "mirrorlists/$tree-$dir.txt") {
			my $mirrorlist = IO::Handle->new();
			open ($mirrorlist, ">mirrorlists/$tree-$dir.txt") or die "unable to write to mirrorlists/$tree-$dir.txt: $!";
			print $mirrorlist "http://yum.opennms.org/$tree/$dir\n";
			close ($mirrorlist);
		}

	}
	print $index "  </ul>\n";
}

print $index <<END;
 </body>
</html>
END

close ($index);

move('.index.html', 'index.html');
