#!/bin/sh

DIRS="common rhel4 rhel5"

for tree in stable unstable; do
	for dir in $DIRS; do
		mkdir -p "$tree/$dir" "caches/$tree/$dir"
		chown -R "root:root" "$tree/$dir" "caches/$tree/$dir"
		createrepo \
			--baseurl "http://yum.opennms.org/$tree/$dir" \
			--outputdir "$tree/$dir" \
			--verbose \
			--cachedir "../../caches/$tree/$dir" \
			--pretty \
			"$tree/$dir"
		mkdir -p repofiles
		cat <<END >"repofiles/$tree-$dir.repo"
[opennms-$tree-$dir]
name=OpenNMS $dir RPMs ($tree)
mirrorlist=http://yum.opennms.org/mirrorlists/$tree-$dir.txt
gpgcheck=1
gpgkey=http://yum.opennms.org/OPENNMS-GPG-KEY
END
		if [ ! -f "mirrorlists/$tree-$dir.txt" ]; then
			cat <<END >"mirrorlists/$tree-$dir.txt"
http://yum.opennms.org/$tree/$dir
END
		fi
	done
done
