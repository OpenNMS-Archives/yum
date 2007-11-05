#!/usr/bin/perl

use strict;
use warnings;

use File::Copy;
use File::Path;
use IO::Handle;

my $signing_password = shift @ARGV;

my @trees   = qw(stable unstable snapshot);
my @oses    = qw(fc4 fc5 fc6 fc7 rhel3 rhel4 rhel5 suse9 suse10);
my $repodir = '/tmp/rpm-repo-' . $$;

my $descriptions = {
	common => 'RPMs Common to All OpenNMS Architectures',
	fc2    => 'Fedora Core 2',
	fc3    => 'Fedora Core 3',
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

my $mirror_roots = [
	'http://opennms.sourceforge.net/yum',
	'http://turbine.slackworks.com/~ranger/opennms-yum',
	'http://yum.opennms.org',
];

my $index = IO::Handle->new();
open($index, '>.index.html.' . $$) or die "unable to write to index.html.$$: $!";
print $index <<END;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
 <head>
  <title>OpenNMS Yum Repository</title>
  <link rel="stylesheet" type="text/css" href="http://opennms.svn.sourceforge.net/svnroot/opennms/opennms/trunk/opennms-webapp/src/main/webapp/css/styles.css" media="screen" />
 </head>
 <body>
  <div id="header">
   <h1 id="headerlogo"><a href="http://www.opennms.org/"><img src="http://opennms.svn.sourceforge.net/svnroot/opennms/opennms/trunk/opennms-webapp/src/main/webapp/images/logo.png" alt="OpenNMS" /></a></h1>  
   <div id="headerinfo">
    <h1>OpenNMS Yum Repository</h1>
   </div>
   <hr />
   <div class="spacer"><!-- --></div>
  </div>
  <div id="content">
   <p>&nbsp;</p>
   <p>
    OpenNMS is available for most RPM-based distributions through Yum.  Quick-start instructions
    are available <a href="http://www.opennms.org/index.php/Installation:Yum">on the OpenNMS
    wiki here</a>.
   </p>
END

my @createrepo = qw(createrepo --verbose --pretty);

for my $tree (@trees) {
	my $title = ucfirst($tree);
	print $index "<h2>$title</h2>\n";
	print $index "<ul>\n";

	print $index "<li>$descriptions->{'common'}(<a href=\"$tree/common\">browse</a>)</li>\n";
	mkpath([$tree . '/common', 'caches/' . $tree . '/common', 'repofiles']);
	create_repo($tree, 'common');

	write_repofile($tree, 'common', $descriptions->{'common'});

	for my $os (@oses) {
		mkpath([$tree . '/' . $os, 'caches/' . $tree . '/' . $os, 'repofiles']);
		if ($os =~ /^rhel/) {
			my $newos = $os;
			$newos =~ s/rhel/centos/;
			symlink($os, $tree . '/' . $newos);
		}
		write_repofile($tree, $os, $descriptions->{$os});

		my $rpmname = make_rpm($tree, $os);
		print $index "<li><a href=\"repofiles/$rpmname\">$descriptions->{$os}</a> (<a href=\"$tree/$os\">browse</a>)</li>\n";

		create_repo($tree, $os);
	}

	print $index "</ul>\n";
}

print $index <<END;
  </div>
  <div id="prefooter"></div>

  <div id="footer">
   <p>
    OpenNMS Copyright \&copy; 2002-2007 <a href="http://www.opennms.com/">The OpenNMS Group, Inc.</a>
    OpenNMS\&reg; is a registered trademark of <a href="http://www.opennms.com">The OpenNMS Group, Inc.</a>
   </p>
  </div>

 </body>
</html>
END

close ($index);

move('.index.html.' . $$, 'index.html');

sub run_command {
	my @command = @_;

	print "- running '@command'\n";
	return system(@command);
}

sub create_repo {
	my $tree = shift;
	my $os   = shift;

	run_command('rm', '-rf', "$tree/$os/.olddata");


	# generate the repo
	run_command(
		@createrepo,
		'--baseurl', "http://yum.opennms.org/$tree/$os",
		'--outputdir', "$tree/$os",
		'--cachedir', "../../caches/$tree/$os",
		"$tree/$os",
	) == 0 or die "unable to run createrepo: $!";

	run_command(
		'/usr/local/yum/bin/yum-arch',
		'-v', '-v', '-l',
		"$tree/$os",
	) == 0 or die "unable to run yum-arch: $!";

	# sign the XML file
	run_command( './detach-sign-file.sh', "$tree/$os/repodata/repomd.xml", $signing_password ) == 0
		or die "unable to sign the repomd.xml file: $!";

	# write the signing public key for convenience
	run_command( "gpg -a --export opennms\@opennms.org > $tree/$os/repodata/repomd.xml.key" ) == 0
		or die "unable to export the public key: $!";
}

sub write_repofile {
	my $tree        = shift;
	my $os          = shift;
	my $description = shift;

	my @ts;
	for my $t (@trees) {
		push(@ts, $t);
		last if ($t eq $tree);
	}

	my $repofile = IO::Handle->new();
	open($repofile, ">repofiles/opennms-$tree-$os.repo") or die "unable to write to repofiles/opennms-$tree-$os.repo: $!";

	for my $treename (@ts) {
		print $repofile <<END;
[opennms-$treename-$os]
name=$description RPMs ($treename)
baseurl=http://yum.opennms.org/$treename/$os
mirrorlist=http://yum.opennms.org/mirrorlists/$treename-$os.txt
failovermethod=priority
gpgcheck=1
gpgkey=http://yum.opennms.org/OPENNMS-GPG-KEY

END
	}

	close($repofile);

	my $mirrorlist = IO::Handle->new();
	open ($mirrorlist, ">mirrorlists/$tree-$os.txt") or die "unable to write to mirrorlists/$tree-$os.txt: $!";
	for my $root (@$mirror_roots) {
		print $mirrorlist "$root/$tree/$os\n";
	}
	close ($mirrorlist);
}

sub make_rpm {
	my $tree = shift;
	my $os   = shift;
	my $return;

	for my $dir ('tmp', 'SPECS', 'SOURCES', 'RPMS', 'SRPMS', 'BUILD') {
		mkpath([$repodir . '/' . $dir]);
	}
	copy("repofiles/opennms-$tree-$os.repo",    $repodir . '/SOURCES/');
	copy("repofiles/opennms-$tree-common.repo", $repodir . '/SOURCES/');

	run_command(
		'rpmbuild',
		'-bb',
		"--buildroot=$repodir/tmp/buildroot",
		'--define', "_topdir $repodir",
		'--define', "_tree $tree",
		'--define', "_osname $os",
		'repo.spec'
	) == 0 or die "unable to build rpm: $!";

	if (opendir(DIR, $repodir . '/RPMS/noarch')) {
		my @files;
		for my $file (readdir(DIR)) {
			chomp($file);
			if ($file =~ /\.rpm$/) {
				push(@files, $file);
			}
		}
		closedir(DIR);
		for my $file (@files) {
			mkpath(["$tree/$os/opennms"]);
			if (not -e "$tree/$os/opennms/$file") {
				move($repodir . '/RPMS/noarch/' . $file, "repofiles/opennms-repo-$tree-$os.noarch.rpm");
			}
		}
		$return = "opennms-repo-$tree-$os.noarch.rpm";
	}

	rmtree($repodir);
	return $return;
}
