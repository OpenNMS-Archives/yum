#!/bin/sh

FROM="$1"; shift
TO="$1"; shift

if [ ! -d "$FROM" ] || [ ! -d "$TO" ]; then
	echo "usage: $0 <from_dir> <to_dir>"
	echo ""
	exit 1
fi

find "$TO" -type l | while read FILE; do
	if [ ! -r "$FILE" ]; then
		echo "removing $FILE"
		rm -f "$FILE"
	fi
done

pushd "$FROM" >/dev/null 2>&1
	find * -name \*.rpm -type f | while read LINE; do
		DIRNAME=`dirname $LINE`
		mkdir -p "../$TO/$DIRNAME"
		if pushd "../$TO/$DIRNAME" >/dev/null 2>&1; then
			if [ -r "../../../../$FROM/$LINE" ]; then
				echo "linking ../../../../$FROM/$LINE"
				ln -s "../../../../$FROM/$LINE" .
			elif [ -r "../../../$FROM/$LINE" ]; then
				echo "linking ../../../$FROM/$LINE"
				ln -s "../../../$FROM/$LINE" .
			elif [ -r "../../$FROM/$LINE" ]; then
				echo "linking ../../$FROM/$LINE"
				ln -s "../../$FROM/$LINE" .
			elif [ -r "../$FROM/$LINE" ]; then
				echo "linking ../$FROM/$LINE"
				ln -s "../$FROM/$LINE" .
			else
				warn "can't find $LINE"
			fi
			popd >/dev/null 2>&1
		else
			echo "WARNING: couldn't enter $TO/$DIRNAME"
		fi
	done
popd >/dev/null 2>&1
