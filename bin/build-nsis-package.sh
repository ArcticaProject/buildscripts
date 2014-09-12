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
#       It also needs to be placed under /cygdrive/d/Build/buildscripts/bin/

export PATH=~/bin:/cygdrive/d/Build/buildscripts/bin:$PATH

GIT_USER="x2go"
GIT_HOSTNAME="code.x2go.org"

GPG_KEY=
NSIS_DISTS_SUPPORTED="mingw32-4.4,mingw32-4.8"
MINGW_DISTROS="qt-4.8"

COMPONENT_MAIN="main"
COMPONENT_NIGHTLY="heuler"
COMPONENT_BUNDLES="baikal"

REPOS_SERVER="code.x2go.org"
GNUPGHOME=$HOME/.gnupg

test -z $1 && { echo "usage: $(basename $0) [<subpath>/]<git-project> {main,main/<codename>,nightly,nightly/<codename>} [<git-checkout>]"; exit -1; }

FORCE_BUILD=${FORCE_BUILD:-"yes"}
NSIS_BUILD_FOR=${NSIS_BUILD_FOR:-"mingw:$MINGW_DISTROS"}

	# FIXME: these should be generated from the env var!!!
	l_DIST=mingw32-4.4
	l_CODENAME=qt-4.8

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
	PROJECT_DIR="/cygdrive/d/Build/GIT/nightly/$l_DIST/$l_CODENAME/x2goclient"
	PKGDIST="/cygdrive/d/Build/pkg-dist/nightly/$l_DIST/$l_CODENAME/x2goclient"

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
		if echo "$MINGW_DISTROS" | grep $ARGV2_CODENAME >/dev/null; then
			NSIS_BUILD_FOR="mingw32-4.4:$ARGV2_CODENAME"
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
	echo "$NSIS_DISTS_SUPPORTED" | grep $l_DIST >/dev/null && {

		TEMP_DIR="$(mktemp -d --tmpdir=$TEMP_BASE)"
		mkdir -p "$TEMP_DIR/$PROJECT"
		chmod 2770 "$TEMP_DIR" -Rf

		cd "$PROJECT_DIR"
		git clone --local "$PROJECT_DIR" "$TEMP_DIR/$PROJECT/"
		cd "$TEMP_DIR/$PROJECT"
		git checkout $CHECKOUT || git checkout master
		find $PROJECT_DIR/../ -type f -maxdepth 0 -mindepth 0 | grep $PROJECT_*.orig.tar.gz &>/dev/null && cp $PROJECT_DIR/../$PROJECT_*.orig.tar.gz ..
		GITREV=$(gitrevno)

		# TODO: Improve generate-nsis-version.pl so that it can be run from another dir
		cd /cygdrive/d/Build/buildscripts/bin/
		./generate-nsis-version.pl $PROJECT_DIR

		cd $PROJECT_DIR
		cp -a debian/changelog txt/

		# create git changelog immediately prior to building the SRPM package
		git --no-pager log --since "2 years ago" --format="%ai %aN (%h) %n%n%x09*%w(68,0,10) %s%d%n" > ChangeLog.gitlog
		cp ChangeLog.gitlog txt/git-info

		cd /cygdrive/d/Build/buildscripts/bin/
		
		nice /cygdrive/d/Build/buildscripts/bin/nsis-builder.bat "${l_DIST}" "${l_CODENAME}"

		rm -Rf "$TEMP_DIR"
		}
	return 0
}

upload_packages() {
	# dupload the new packages to the reprepro repository
	echo "$NSIS_BUILD_FOR" | sed -e 's/ /\n/g' | while read line; do

		# FIXME: this should be handled at the beginning of this script!!!
		MINGW_REPOS_BASE=/srv/sites/x2go.org/code/releases/binary-win32/x2goclient/heuler/

		# create remote directories in archive
		0</dev/null ssh $REPOS_SERVER mkdir -p $MINGW_REPOS_BASE/$l_DIST/$l_CODENAME/

		# remove installer packages that are older than 30 days
		0</dev/null ssh $REPOS_SERVER "find \"$MINGW_REPOS_BASE/$l_DIST/$l_CODENAME/*\" -mtime +30 -name \"x2goclient-*-setup.exe\" 2>/dev/null | while read installer; do rm -f "$installer"; done
		
		# Ensure that the package is world-readable before being uploaded to an HTTP/HTTPS server.
		# Otherwise, sometimes cygwin sftp/scp uploads files with 000 permissions.
		# What probably happens is that Cygwin is enumerates the windows permissions as a bunch of ACLs, and sets the octal permissions to 000. 
		#
		# 2014-07-13
		# Commenting this out because for some reason, it could not find the files, thus causing the build to fail.
		# Furthermore, the permissions on the uploaded builds are fine right now.
		# The file not found error was:
		# chmod: Zugriff auf Â»/cygdrive/d/Build/GIT/nightly/x2goclient/nsis/x2goclient-*-setup.exeâ€œ nicht mÃ¶glich: Datei oder Verzeichnis nicht gefunden
		# chmod a+r /cygdrive/d/Build/GIT/nightly/$PROJECT/nsis/$PROJECT-*-setup.exe

		# copy new installer to download location
		# FIXME: this should work scp /cygdrive/d/Build/pkg-dist/$l_DIST/$l_CODENAME/i386/$PROJECT-*-setup.exe" "$MINGW_REPOS_BASE/$l_DIST/$l_CODENAME/"
		scp /cygdrive/d/Build/GIT/nightly/$l_DIST/$l_CODENAME/$PROJECT/nsis/$PROJECT-*-setup.exe $REPOS_SERVER:"$MINGW_REPOS_BASE/$l_DIST/$l_CODENAME/"
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
