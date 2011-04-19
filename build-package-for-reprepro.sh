#!/bin/bash

# Copyright (C) 2010 by Mike Gabriel <mike.gabriel@das-netzwerkteam.de>
#
# This programme is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This programme is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the
# Free Software Foundation, Inc.,
# 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA.

PACKAGE=$(basename `pwd`)

$PKGDIST="$(pwd)/../pkg-dist/$PACKAGE"
mkdir $PKGDIST

rm -f $PKGDIST/$PACKAGE_*.changes
rm -f $PKGDIST/$PACKAGE_*.upload
rm -f $PKGDIST/$PACKAGE_*.build
rm -f $PKGDIST/$PACKAGE_*.dsc
rm -f $PKGDIST/$PACKAGE_*.tar.gz
rm -f $PKGDIST/$PACKAGE*.deb

TEMP_DIR="$(mktemp -d)"
git clone git://code.x2go.org/$PACKAGE.git $TEMP_DIR/
cd $TEMP_DIR/$PACKAGE

BUILDS_FOR="""
debian: sid wheezy squeeze
ubuntu: lucid maverick natty
"""

for DIST_LIST in $BUILDS_FOR; do 
	l_DIST=$(echo $DIST_LIST | cut -d":" -f1)
	CODENAMES=$(echo $DIST_LIST | cut -d":" -f2-)
	for l_CODENAME in $CODENAMES; do 
		DIST=$l_DIST CODENAME=$l_CODENAME ARCH=amd64 pdebuild --buildresults $PKGDIST/$l_DIST/$l_CODENAME
		DIST=$l_DIST CODENAME=$l_CODENAME ARCH=i386  pdebuild --buildresults $PKGDIST/$l_DIST/$l_CODENAME
	done
done
cd -

cd $PKGDIST
for DIST_LIST in $BUILDS_FOR; do 
	l_DIST=$(echo $DIST_LIST | cut -d":" -f1)
	CODENAMES=$(echo $DIST_LIST | cut -d":" -f2-)
	for l_CODENAME in $CODENAMES; do 
		cd $PKGDIST/$l_DIST/$l_CODENAME
		dupload --to x2go-$l_DIST-$l_CODENAME $PACKAGE_*.dsc
		dupload --to x2go-$l_DIST-$l_CODENAME $PACKAGE_*.changes
		cd -
	done
done
cd -

#rm -Rf $TEMP_DIR
