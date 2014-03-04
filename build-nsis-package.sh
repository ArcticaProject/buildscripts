#!/bin/bash

# Copyright (C) 2011-2013 by Mike Gabriel <mike.gabriel@das-netzwerkteam.de>
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

# Note: This script was adapted from build-deb-package. It is still very
#       rough around the edges. For example, many lines are commented out
#       and many values are hardcoded.
#       It needs to be run under cygwin.
#       It also needs to be placed under /cygdrive/d/Build/scripts/

export PATH=~/bin:/cygdrive/d/Build/scripts:$PATH

GIT_USER="gituser"
GIT_HOSTNAME="code.x2go.org"

DEBEMAIL="firstname.lastname@mydomain.org"
DEBFULLNAME="Firstname Lastname"
GPG_KEY=
NSIS_DISTS_SUPPORTED="mingw"
MINGW_DISTROS="current"

COMPONENT_MAIN="main"
COMPONENT_NIGHTLY="heuler"
COMPONENT_BUNDLES="bundle-release1 bundle-release2"
REPOS_SERVER="packages.mydomain.org"
PACKAGES_WITHOUT_OTHERMIRROR="keyring"
GNUPGHOME=$HOME/.gnupg

test -z $1 && { echo "usage: $(basename $0) [<subpath>/]<git-project> {main,main/<codename>,nightly,nightly/<codename>} [<git-checkout>]"; exit -1; }

PREFIX=$(echo `basename $0` | cut -d"-" -f1)
#test -f ~/.buildscripts/$PREFIX.conf && . ~/.buildscripts/$PREFIX.conf || { echo "$0 has no valid context prefix..."; exit -1; }

FORCE_BUILD=${FORCE_BUILD:-"yes"}
NSIS_BUILD_FOR=${NSIS_BUILD_FOR:-"mingw:$MINGW_DISTROS"}


set -ex

set_vars() {
	USE_SUDO="no"
	PDEBUILD="pdebuild --pbuilder qemubuilder"
	TEMP_BASE="/cygdrive/d/Build/tmp"
	mkdir -p "$TEMP_BASE"
	chmod 2770 "$TEMP_BASE"

	# first argv is the name of the Git project
	PROJECT_PATH="$1"
	PROJECT_PATH=${PROJECT_PATH/%.git/}
	PROJECT="$(basename $PROJECT_PATH)"

	# grab repository component area from command line (2nd argv) or guess it
	ARGV2_COMPONENT="$(echo "$2/" | cut -d"/" -f1)"
	ARGV2_CODENAME="$(echo "$2/" | cut -d"/" -f2)"
	COMPONENT="${ARGV2_COMPONENT:-${COMPONENT:-$COMPONENT_NIGHTLY}}"
	CODENAMES="${ARGV2_CODENAME:-${CODENAMES}}"
	[ -n "$ARGV2_CODENAME" ] && FORCE_BUILD="yes" || true
	DATE="${DATE:-$(date +%Y%m%d)}"
	if [ "x$COMPONENT" = "x$COMPONENT_MAIN" ]; then
		CHECKOUT="${3:-build-main}"
	elif echo "$COMPONENT_RELEASES" | grep "$COMPONENT" >/dev/null; then
		CHECKOUT="${3:-build-$COMPONENT}"
	elif [ "x$COMPONENT" = "x$COMPONENT_NIGHTLY" ]; then
		CHECKOUT="${3:-master}"
	else
		echo "error: no such package component area for this Git project. Aborting..."
		exit -1
	fi
	# the DATE might be given as ,,today'' from the command line
	[ "x$DATE" = "xtoday" ] && DATE="$(date +%Y%m%d)"

	# setting paths
	PROJECT_DIR="/cygdrive/d/Build/GIT/nightly/x2goclient"
	PKGDIST="/cygdrive/d/Build/pkg-dist/nightly/x2goclient"

	# build for other architectures than amd64/i386
	EXTRA_ARCHS="${EXTRA_ARCHS:-}"
	EXTRA_ARCHS_ONLY="${EXTRA_ARCHS_ONLY:-}"

	# lock file
	LOCK_FILE=$PROJECT_DIR/../.$PROJECT.lock

	# creating paths
	mkdir -p "$TEMP_BASE"
	mkdir -p "$PROJECT_DIR"
#	mkdir -p "$PKGDIST"

	return 0
}

prepare_workspace() {
	# make sure our local working copy is up to date...

	if [ -d "$PROJECT_DIR/.git" ]; then 
		cd "$PROJECT_DIR" && git reset --hard
		git checkout --force $CHECKOUT || git checkout --force -b $CHECKOUT
		git pull origin $CHECKOUT
		git fetch origin upstream:upstream || true
		git fetch origin pristine-tar:pristine-tar || true
		# and again, get the $CHECKOUT refspec in pure state
		git reset --hard
		git clean -df
	else
		cd "$(dirname $PROJECT_DIR)"
		git clone git://$GIT_HOSTNAME/$PROJECT_PATH.git
		cd "$PROJECT"
		git checkout --force $CHECKOUT || git checkout --force -b $CHECKOUT;
		git fetch origin upstream:upstream
		git fetch origin pristine-tar:pristine-tar || true
		git clean -df
	fi

	GIT_OBJECT_ID=`git show-ref -s heads/master`
	cd "$PROJECT_DIR"

	# by default we build for all current debian versions
	if [ "x$ARGV2_CODENAME" != "x" ]; then
		if echo "$DEBIAN_DISTROS" | grep $ARGV2_CODENAME >/dev/null; then
			NSIS_BUILD_FOR="debian:$ARGV2_CODENAME"
		elif echo "$UBUNTU_DISTROS" | grep $ARGV2_CODENAME >/dev/null; then
			NSIS_BUILD_FOR="ubuntu:$ARGV2_CODENAME"
		fi
	fi
	return 0
}

clear_pkgdist() {
	# pkgdist directory cleanup
	echo "$NSIS_BUILD_FOR" | sed -e 's/ /\n/g' | while read line; do
		l_DIST="$(echo ${line/: /:} | cut -d":" -f1 | tr [:upper:] [:lower:])"
		l_CODENAMES="${CODENAMES:-$(echo ${line/: /:} | cut -d":" -f2- | sed -e 's/,/ /g' | tr [:upper:] [:lower:])}"
		echo "$NSIS_DISTS_SUPPORTED" | grep $l_DIST >/dev/null && {
			for l_CODENAME in $l_CODENAMES; do

				# in case we build a special CODENAME (squeeze, wheezy, lucid, ...) do skip
				# the wrong distribution here...
				test -z $CODENAMES || echo $line | grep $CODENAMES || break

				if [ "x$EXTRA_ARCHS_ONLY" = "x" ]; then
					for l_ARCH in amd64 i386; do
						[ "x$SKIP_ARCH" != "x$l_ARCH" ] && {
							mkdir -p "$PKGDIST/$l_DIST/$l_CODENAME/$l_ARCH"
							rm -f "$PKGDIST/$l_DIST/$l_CODENAME/$l_ARCH/dupload.conf"
							rm -f "$PKGDIST/$l_DIST/$l_CODENAME/$l_ARCH/$PROJECT_"*.changes
							rm -f "$PKGDIST/$l_DIST/$l_CODENAME/$l_ARCH/$PROJECT_"*.upload
							rm -f "$PKGDIST/$l_DIST/$l_CODENAME/$l_ARCH/$PROJECT_"*.build
							rm -f "$PKGDIST/$l_DIST/$l_CODENAME/$l_ARCH/$PROJECT_"*.dsc
							rm -f "$PKGDIST/$l_DIST/$l_CODENAME/$l_ARCH/$PROJECT_"*.tar.gz
							rm -f "$PKGDIST/$l_DIST/$l_CODENAME/$l_ARCH/"*.deb
						}
					done
				fi
				for l_EXTRA_ARCH in $EXTRA_ARCHS; do 
					mkdir -p "$PKGDIST/$l_DIST/$l_CODENAME/$l_EXTRA_ARCH"
					rm -f "$PKGDIST/$l_DIST/$l_CODENAME/$l_EXTRA_ARCH/dupload.conf"
					rm -f "$PKGDIST/$l_DIST/$l_CODENAME/$l_EXTRA_ARCH/$PROJECT_"*.changes
					rm -f "$PKGDIST/$l_DIST/$l_CODENAME/$l_EXTRA_ARCH/$PROJECT_"*.upload
					rm -f "$PKGDIST/$l_DIST/$l_CODENAME/$l_EXTRA_ARCH/$PROJECT_"*.build
					rm -f "$PKGDIST/$l_DIST/$l_CODENAME/$l_EXTRA_ARCH/$PROJECT_"*.dsc
					rm -f "$PKGDIST/$l_DIST/$l_CODENAME/$l_EXTRA_ARCH/$PROJECT_"*.tar.gz
					rm -f "$PKGDIST/$l_DIST/$l_CODENAME/$l_EXTRA_ARCH/"*.deb
				done
			done
		}
	done
	return 0
}

build_packages() {
	# use pbuilder for building all variants of this package
	echo "$NSIS_BUILD_FOR" | sed -e 's/ /\n/g' | while read line; do
		l_DIST="$(echo ${line/: /:} | cut -d":" -f1 | tr [:upper:] [:lower:])"
		l_CODENAMES="${CODENAMES:-$(echo ${line/: /:} | cut -d":" -f2- | sed -e 's/,/ /g' | tr [:upper:] [:lower:])}"
		echo "$NSIS_DISTS_SUPPORTED" | grep $l_DIST >/dev/null && {
			for l_CODENAME in $l_CODENAMES; do

				# in case we build a special CODENAME (squeeze, wheezy, lucid, ...) do skip
				# the wrong distribution here...
				#test -z $CODENAMES || echo $line | grep $CODENAMES || break

				TEMP_DIR="$(mktemp -d --tmpdir=$TEMP_BASE)"
				mkdir -p "$TEMP_DIR/$PROJECT"
				chmod 2770 "$TEMP_DIR" -Rf

				cd "$PROJECT_DIR"
				git clone --local "$PROJECT_DIR" "$TEMP_DIR/$PROJECT/"
				cd "$TEMP_DIR/$PROJECT"
				git checkout $CHECKOUT || git checkout master
				find $PROJECT_DIR/../ -type f -maxdepth 0 -mindepth 0 | grep $PROJECT_*.orig.tar.gz &>/dev/null && cp $PROJECT_DIR/../$PROJECT_*.orig.tar.gz ..
				GITREV=$(gitrevno)

				# we always build native packages for our repos
				SA_OPTION=""

				# we always build native packages for our repos
				SA_OPTION=""
				test -f debian/source/format && cat debian/source/format | egrep '^3.0.*\(quilt\)$' >/dev/null && {
					git fetch origin upstream:upstream
					UPSTREAM_VERSION=$(dpkg-parsechangelog | grep Version: | cut -d " " -f2 | sed -e 's/-.*//' -e 's/^.*://')
					REVISION=$(dpkg-parsechangelog | grep Version: | cut -d " " -f2 | sed -e 's/.*-//')
					git archive --prefix=${PROJECT}-${UPSTREAM_VERSION}/ -o ../${PROJECT}_${UPSTREAM_VERSION}.orig.tar.gz upstream/${UPSTREAM_VERSION} && {
						SA_OPTION="--debbuildopts=-sa"
					} || echo "1.0" > debian/source/format
				}

				# for Ubuntu version is the codename of the distribution release
				VERSION=$l_CODENAME

				# translate the version name for Debian releases
				[ "x$l_CODENAME" = "xsid" ] && VERSION=unstable
				#[ "x$l_CODENAME" = "xjessie" ] && VERSION=testing
				#[ "x$l_CODENAME" = "xwheezy" ] && VERSION=stable
				#[ "x$l_CODENAME" = "xoldstable" ] && VERSION=oldstable

				# modify the section for non-main package builds
				[ "x$COMPONENT" != "xmain" ] && {
					mv debian/control debian/control.tmp
					cat debian/control.tmp | sed  "s#Section:[\ ]*\(.*\)#Section: $COMPONENT/\1#g" > debian/control
				}

				# modify changelog for this build
#				if [ "$COMPONENT" != "$COMPONENT_NIGHTLY" ]; then
#					dch --distribution $VERSION --force-distribution -l "+git$DATE.$GITREV+$l_CODENAME.$COMPONENT." "Auto-built $l_DIST $l_CODENAME package for $REPOS_SERVER repository (Git commit: $GIT_OBJECT_ID)."
#				else
#					dch --distribution $VERSION --force-distribution -l "~git$DATE.$GITREV+$l_CODENAME.$COMPONENT." "Development-Snapshot!!! Auto-built $l_DIST $l_CODENAME package for $REPOS_SERVER repository (Git commit: $GIT_OBJECT_ID)."
#				fi
#				mkdir -p $PKGDIST/$l_DIST/$l_CODENAME/{amd64,i386}
				OTHERMIRROR=""
				if [ "x$COMPONENT" = "x$COMPONENT_NIGHTLY" ]; then
					echo $PACKAGE_WITHOUT_OTHERMIRROR | grep $PROJECT >/dev/null || OTHERMIRROR="deb http://$REPOS_SERVER/$l_DIST $l_CODENAME $COMPONENT_MAIN $COMPONENT"
				else
					echo $PACKAGE_WITHOUT_OTHERMIRROR | grep $PROJECT >/dev/null || OTHERMIRROR="deb http://$REPOS_SERVER/$l_DIST $l_CODENAME $COMPONENT"
				fi
				if [ $PROJECT = "x2gomatebindings" ]; then
					OTHERMIRROR="deb http://packages.mate-desktop.org/repo/debian $l_CODENAME main"
				fi

				l_DIST=mingw32-4.4
				l_CODENAME=qt-4.8

				# TODO: Improve generate-nsis-version.pl so that it can be run from another dir.				
				cd /cygdrive/d/Build/scripts/
				./generate-nsis-version.pl

				nice /cygdrive/d/Build/scripts/nsis-builder.bat --buildresult "D:\\Build\\Scripts\\test\\$l_DIST\\$l_CODENAME\\i386"

				rm -Rf "$TEMP_DIR"
			done
		}
	done
	return 0
}

upload_packages() {
	# dupload the new packages to the reprepro repository
	echo "$NSIS_BUILD_FOR" | sed -e 's/ /\n/g' | while read line; do
		l_DIST="$(echo ${line/: /:} | cut -d":" -f1 | tr [:upper:] [:lower:])"
		l_CODENAMES="${CODENAMES:-$(echo ${line/: /:} | cut -d":" -f2- | sed -e 's/,/ /g' | tr [:upper:] [:lower:])}"
		for l_CODENAME in $l_CODENAMES; do

			# in case we build a special CODENAME (squeeze, wheezy, lucid, ...) do skip
			# the wrong distribution here...
			test -z $CODENAMES || echo $line | grep $CODENAMES || break

			if [ "x$EXTRA_ARCHS_ONLY" = "x" ]; then	
				for l_ARCH in amd64 i386; do
					[ "x$SKIP_ARCH" != "x$l_ARCH" ] && {
						cd "$PKGDIST/$l_DIST/$l_CODENAME/$l_ARCH"
						test -f ./dupload.conf || ln -s ~/.dupload.conf.$PREFIX ./dupload.conf
						ls $PROJECT_*.changes &>/dev/null && dupload -c --to $PREFIX-$l_DIST-$l_CODENAME $PROJECT_*.changes 0<&-
					}
				done
			fi
			for l_EXTRA_ARCH in $EXTRA_ARCHS; do 
				cd "$PKGDIST/$l_DIST/$l_CODENAME/$l_EXTRA_ARCH"
				test -f ./dupload.conf || ln -s ~/.dupload.conf.$PREFIX ./dupload.conf
				ls $PROJECT_*.changes &>/dev/null && dupload -c --to $PREFIX-$l_DIST-$l_CODENAME $PROJECT_*.changes 0<&-
			done
		done
	done
	return 0
}

wait_for_lock() {
	while [ -f $LOCK_FILE ]; do
		pid=$(head -n1 $LOCK_FILE)
		if ! ps $pid 1>/dev/null; then rm -f $LOCK_FILE
		else
			echo "PROJECT directory is locked, sleeping for 10 seconds..."
			sleep 10
		fi
	done
}

lock_workspace() {
	wait_for_lock
	echo $$ > $LOCK_FILE
}

unlock_workspace() {
	rm -f $LOCK_FILE
}

delay_build() {
	sleep $[ ( $RANDOM % 30 )  + 1 ]s
}

### MAIN ###
set_vars $@ && {
	if [ "x$(basename $0)" = "xbuild-nsis-package.sh" ] || [ "x$(basename $0)" = "xbuild+upload-nsis-package.sh" ]; then
		cd $PROJECT_DIR && pkgneedsbuild $CHECKOUT || [ "$FORCE_BUILD" = "yes" ] && {
			if [ "x$FORCE_BUILD" = "xyes" ]; then
				delay_build
			fi
			lock_workspace
			prepare_workspace && {
				unlock_workspace
#				clear_pkgdist
				build_packages
			}
			unlock_workspace
		}
	fi
	if [ "x$(basename $0)" = "xupload-nsis-package.sh" ] || [ "x$(basename $0)" = "xbuild+upload-nsis-package.sh" ]; then
		upload_packages
	fi
}
