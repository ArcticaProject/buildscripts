#!/bin/bash

export OUT="cygwin files and packages.csv"

if [[ $# == 0 ]]; then
	echo "Example usage: $0 /bin/sh.exe /bin/libgcc_s-1.dll"
	echo "Output will be appended to \"${OUT}\""
        echo "This script is intended to help with GPL compliance."
	echo "Currently this script does not identify the source package,"
        echo "Only the binary package."
	echo "Browse a cygwin mirror or use Google/DuckDuckGo to identify the source package."
fi

echo "File,Binary Package w/ Version,Source Package" >> "${OUT}"

for file in "$@"
do
        binPkg=`cygcheck -f $file| tr -d '\r' | tr -d '\n'`
        echo "${file},${binPkg}," >> "${OUT}"
done
