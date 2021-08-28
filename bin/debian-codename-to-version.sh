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
# corresponding numerical version (based on year and month
# of the release.)
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
	# sid | unstable's version number must be
	# a bit higher than the current testing version
	# (which is known early in advance to the next
	# upcoming release).
	("sid"|"unstable") echo "12.01";;

	("bookworm"|"stable") echo "12";;

	("bullseye"|"stable") echo "11";;
	("buster"|"oldstable") echo "10";;
	("stretch"|"oldoldstable") echo "9";;
	("jessie") echo "8";;
	("wheezy") echo "7";;
	("squeeze") echo "6";;
	("lenny") echo "5";;
	("etch") echo "4";;
	("sarge") echo "3.1";;
	("woody") echo "3.0";;
	("potato") echo "2.2";;
	("slink") echo "2.1";;
	("hamm") echo "2.0";;
	("bo") echo "1.3";;
	("rex") echo "1.2";;
	("buzz") echo "1.1";;

	(*) ret="1";;
esac

exit "${ret}"
