#!/bin/sh

FILE="$1"; shift

cat <<END >upload.lftp
open ftp://upload.sourceforge.net/incoming
put $FILE
exit
END

lftp -f upload.lftp
