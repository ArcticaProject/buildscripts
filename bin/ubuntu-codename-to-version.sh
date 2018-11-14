#!/bin/bash

# Copyright (C) 2016      by Mihai Moldovan <ionic@ionic.de>
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

export PATH="${HOME}/bin:${PATH}"

# ${CDPATH} could lead to some very nasty problems. Better unset it.
unset CDPATH

# Takes a Debian code name and converts it into the
# corresponding numerical version.
# The result is printed as a string with a trailing newline.
# The return code is either 0, iff mapping was successful,
# or 1 if the code name is unknown and mapping failed.

# Where supported (BASH 4 and higher), automatically
# lower-case the codename argument.
if [ -n "${BASH_VERSINFO[0]}" ] && [ "${BASH_VERSINFO[0]}" -gt 3 ]; then
	typeset -l codename
fi
codename="${1:?"No code name provided."}"

if [ -z "${BASH_VERSINFO[0]}" ] || [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
	codename="$(tr '[:upper:]' '[:lower:]' <<< "${codename}")"
fi

typeset -i ret="0"

case "${codename}" in
	# The first version number is actually "fake",
	# but given it's a rolling release,
	# we can't really do better here.
	("devel") echo "9999";;

	("disco") echo "19.04";;
	("cosmic") echo "18.10";;
	("bionic") echo "18.04";;
	("artful") echo "17.10";;
	("zesty") echo "17.04";;
	("yakkety") echo "16.10";;
	("xenial") echo "16.04";;
	("wily") echo "15.10";;
	("vivid") echo "15.04";;
	("utopic") echo "14.10";;
	("trusty") echo "14.04";;
	("saucy") echo "13.10";;
	("raring") echo "13.04";;
	("precise") echo "12.04";;
	("quantal") echo "12.10";;
	("oneiric") echo "11.10";;
	("natty") echo "11.04";;
	("maverick") echo "10.10";;
	("lucid") echo "10.04";;
	("karmic") echo "9.10";;
	("jaunty") echo "9.04";;
	("intrepid") echo "8.10";;
	("hardy") echo "8.04";;
	("gutsy") echo "7.10";;
	("feisty") echo "7.04";;
	("edgy") echo "6.10";;
	("dapper") echo "6.06";;
	("breezy") echo "5.10";;
	("hoary") echo "5.04";;
	("warty") echo "4.10";;

	(*) ret="1";;
esac

exit "${ret}"
