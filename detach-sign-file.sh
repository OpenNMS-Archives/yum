#!/bin/sh

MYDIR=`dirname $0`
TOPDIR=`cd $MYDIR; pwd`

FILE="$1"; shift
PASSWORD="$1"; shift

if [ -d "../.gnupg" ]; then
	GPGHOMEDIRCMD="--homedir ../.gnupg --default-key opennms@opennms.org"
fi

if [ ! -f "$FILE" ]; then
	exit 1
fi

if [ -z "$PASSWORD" ]; then
	echo "no password!"
	exit 1
fi

expect -c "set timeout -1; spawn gpg $GPGHOMEDIRCMD --yes -a --detach-sign $FILE; match_max 100000; expect -exact \"Enter passphrase: \"; send -- \"$PASSWORD\\r\"; expect eof"
