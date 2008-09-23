#!/usr/bin/perl

use strict;
use warnings;

use File::Basename;
use File::Copy;
use File::Find;
use File::Path;
use IO::Handle;

my $make_rpm = 0;
my $signing_password = shift(@ARGV);
while ($ARGV[0] =~ /^--/) {
	if ($ARGV[0] eq "--make-rpm") {
		$make_rpm = 1;
		shift(@ARGV);
	}
}

my @trees   = qw(stable testing unstable snapshot);
my @oses    = qw(fc4 fc5 fc6 fc7 fc8 fc9 mandriva2007 mandriva2008 rhel3 rhel4 rhel5 suse9 suse10);
my $repodir = '/tmp/rpm-repo-' . $$;

if (@ARGV) {
	@oses = @ARGV;
}

my $descriptions = {
	common       => 'RPMs Common to All OpenNMS Architectures',
	fc2          => 'Fedora Core 2',
	fc3          => 'Fedora Core 3',
	fc4          => 'Fedora Core 4',
	fc5          => 'Fedora Core 5',
	fc6          => 'Fedora Core 6',
	fc7          => 'Fedora Core 7',
	fc8          => 'Fedora Core 8',
	fc9          => 'Fedora Core 9',
	mandriva2007 => 'Mandriva 2007',
	mandriva2008 => 'Mandriva 2008',
	rhel3        => 'RedHat Enterprise Linux 3.x and CentOS 3.x',
	rhel4        => 'RedHat Enterprise Linux 4.x and CentOS 4.x',
	rhel5        => 'RedHat Enterprise Linux 5.x and CentOS 5.x',
	suse9        => 'SuSE Linux 9.x',
	suse10       => 'SuSE Linux 10.x',
};

my $mirror_roots = [
	'http://yum.opennms.org',
];

my $index = IO::Handle->new();
open($index, '>.index.html.' . $$) or die "unable to write to index.html.$$: $!";
print $index <<END;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
 <head>
  <title>OpenNMS Yum Repository</title>
  <link rel="stylesheet" type="text/css" href="style.css" media="screen" />
 </head>
 <body>
  <div id="header">
   <h1 id="headerlogo"><a href="http://www.opennms.org/"><img src="logo.png" alt="OpenNMS" /></a></h1>  
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

	print $index "<li>$descriptions->{'common'} (<a href=\"$tree/common\">browse</a>)</li>\n";
	mkpath([$tree . '/common', 'repofiles']);
	create_repo($tree, 'common');

	write_repofile($tree, 'common', $descriptions->{'common'});

	for my $os (@oses) {
		mkpath([$tree . '/' . $os, 'repofiles']);
		if ($os =~ /^rhel/) {
			my $newos = $os;
			$newos =~ s/rhel/centos/;
			symlink($os, $tree . '/' . $newos);
		}
		write_repofile($tree, $os, $descriptions->{$os});

		make_rpm($tree, $os);
		my $rpmname = get_repo_file_name($tree, $os);

		if (defined $rpmname and -e "repofiles/$rpmname") {
			print $index "<li><a href=\"repofiles/$rpmname\">$descriptions->{$os}</a> (<a href=\"$tree/$os\">browse</a>)</li>\n";
		} else {
			print $index "<li>$descriptions->{$os} (<a href=\"$tree/$os\">browse</a>)</li>\n";
		}

		create_repo($tree, $os);
	}

	print $index "</ul>\n";
}

print $index <<END;
  </div>
  <div id="prefooter"></div>

  <div id="footer">
   <p>
    OpenNMS Copyright \&copy; 2002-2008 <a href="http://www.opennms.com/">The OpenNMS Group, Inc.</a>
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

	if ($os =~ /^mandriva/) {

		chdir("$tree/$os");

		make_symlinks("../common", ".");
		clean_symlinks(".");

		run_command(
			'../../genhdlist',
			'--nobadrpm',
		) == 0 or die "unable to run genhdlist: $!";

		unlink('list');
		mkpath("media_info");
		move("hdlist.cz", "media_info/hdlist.cz");
		move("synthesis.hdlist.cz", "media_info/synthesis.hdlist.cz");
		chdir("media_info");
		symlink("../../../OPENNMS-GPG-KEY", "pubkey");
		chdir("..");

		chdir("../..");

	} else {

		# generate the repo

		mkpath "$tree/$os";
		mkpath "caches/$tree/$os";
		run_command(
			@createrepo,
#			'--baseurl', "http://yum.opennms.org/$tree/$os",
			'--outputdir', "$tree/$os",
			'--cachedir', "../../caches/$tree/$os",
			"$tree/$os",
		) == 0 or die "unable to run createrepo: $!";

		if (-x '/usr/local/yum/bin/yum-arch') {
			run_command(
				'/usr/local/yum/bin/yum-arch',
				'-v', '-v', '-l',
				"$tree/$os",
			) == 0 or die "unable to run yum-arch: $!";
		} else {
			warn "yum-arch was not executable!";
		}

		# sign the XML file
		run_command( './detach-sign-file.sh', "$tree/$os/repodata/repomd.xml", $signing_password ) == 0
			or die "unable to sign the repomd.xml file: $!";

		# write the signing public key for convenience
		my $gpghomedircmd = "";
		if (-d '../.gnupg') {
			$gpghomedircmd = "--homedir ../.gnupg";
		}
		run_command( "gpg $gpghomedircmd -a --export opennms\@opennms.org > $tree/$os/repodata/repomd.xml.key" ) == 0
			or die "unable to export the public key: $!";

	}

}

sub make_symlinks {
	my $from = shift;
	my $to   = shift;

	find({
		wanted => sub {
			my $filename = $_;
			my $basename = basename($filename);
			symlink($File::Find::name, $to . '/' . $basename) if (/\.rpm$/);
		},
		no_chdir => 1,
	}, $from);
}

sub clean_symlinks {
	my $dir = shift;

	find ({
		wanted => sub {
			unlink($_) if (not -e $_);
		},
	}, $dir);
}

sub write_repofile {
	my $tree        = shift;
	my $os          = shift;
	my $description = shift;

	return if ($os =~ /^mandriva/);
	my ($baseurl, $mirrorlist);

	my @ts;
	for my $t (@trees) {
		next if ($tree eq 'unstable' and $t eq 'testing');
		push(@ts, $t);
		last if ($t eq $tree);
	}

	my $repofile = IO::Handle->new();
	open($repofile, ">repofiles/opennms-$tree-$os.repo") or die "unable to write to repofiles/opennms-$tree-$os.repo: $!";

	for my $treename (@ts) {
#		can't do this for now since it ends up causing 404s  :(
#		$baseurl = "http://yum.opennms.org/flat/$treename/$os";
#		$mirrorlist = "http://yum.opennms.org/flat/$treename/$os/mirrorlist.txt";

		$baseurl = "http://yum.opennms.org/$treename/$os";
		$mirrorlist = "http://yum.opennms.org/mirrorlists/$treename-$os.txt";

		print $repofile <<END;
[opennms-$treename-$os]
name=$description RPMs ($treename)
baseurl=$baseurl
failovermethod=roundrobin
gpgcheck=1
gpgkey=http://yum.opennms.org/OPENNMS-GPG-KEY

END
	}

	close($repofile);

	my $mirrorfile = IO::Handle->new();
	open ($mirrorfile, ">mirrorlists/$tree-$os.txt") or die "unable to write to mirrorlists/$tree-$os.txt: $!";
	for my $root (@$mirror_roots) {
		print $mirrorfile "$root/$tree/$os\n";
	}
	close ($mirrorfile);
}

sub make_rpm {
	my $tree = shift;
	my $os   = shift;
	my $outputdir = "$tree/$os/opennms";
	my $outputfile = get_repo_file_name($tree, $os);
	my $return;

	return if ($os =~ /^mandriva/);

	if (not $make_rpm) {
		if (-r $outputdir . '/' . $outputfile) {
			return $outputfile;
		} else {
			return undef;
		}
	}

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
				move($repodir . '/RPMS/noarch/' . $file, "repofiles/$outputfile");
			}
		}
		$return = $outputfile;
	}

	rmtree($repodir);
	return $return;
}

sub get_repo_file_name {
	my $tree = shift;
	my $os = shift;
	return "opennms-repo-$tree-$os.noarch.rpm";
}
