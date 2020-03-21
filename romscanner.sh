#!/bin/bash

# romscanner.sh scans MAME and FBA roms, downloads thumbnails and creates playlists.
# Copyright (C) 2020 Ramón Román Castro <ramonromancastro@gmail.com>

# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the
# Free Software Foundation; either version 2 of the License, or (at your
# option) any later version.

# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
# Public License for more details.

# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 59 Temple
# Place, Suite 330, Boston, MA 02111-1307 USA

shopt -s nullglob

# Constants

VERSION="1.3"

# Configuration variables

storage_path=/storage
roms_path=
thumbnails_path=
playlists_path=
cores_path=/tmp/cores

# Parameters

p_dats=
p_force=

# Internal variables

mame_title="Arcade (MAME 2003)"
mame_dat_url="https://raw.githubusercontent.com/libretro/mame2003-libretro/master/metadata/mame2003.xml"
mame_dat=mame.dat
mame_playlists="MAME2003.lpl"
mame_playlists_path=
mame_thumbnails_path=
mame_roms_path=
mame_cores_path=
mame_thumbnails_url="https://raw.githubusercontent.com/libretro/libretro-thumbnails/master/MAME"

fba_title="Arcade (FB Alpha - Arcade Games)"
fba_dat_url="https://raw.githubusercontent.com/libretro/fbalpha/master/dats/FB%20Alpha%20(ClrMame%20Pro%20XML%2C%20Arcade%20only).dat"
fba_dat=fba.dat
fba_playlists="FB Alpha - Arcade Games.lpl"
fba_playlists_path=
fba_thumbnails_path=
fba_roms_path=
fba_cores_path=
fba_thumbnails_url="https://raw.githubusercontent.com/libretro/libretro-thumbnails/master/FB%20Alpha%20-%20Arcade%20Games"

romsmissing=0
romsfound=0
thumbsmissing=0
thumbsdownloaded=0

fillVariables(){
  roms_path=${storage_path}/roms
  thumbnails_path=${storage_path}/thumbnails
  playlists_path=${storage_path}/playlists

  mame_playlists_path="${playlists_path}/${mame_playlists}"
  mame_thumbnails_path="${thumbnails_path}/MAME2003"
  mame_roms_path="${roms_path}/mame"
  mame_cores_path="${cores_path}/mame2003_libretro.so"

  fba_playlists_path="${playlists_path}/${fba_playlists}"
  fba_thumbnails_path="${thumbnails_path}/FB Alpha - Arcade Games"
  fba_roms_path="${roms_path}/fba"
  fba_cores_path="${cores_path}/fbalpha_libretro.so"
}

getName () {
  local name=$(sed -n '/<game name="'$1'"/,/<\/description>/p' "$2" | sed -n 's:.*<description>\(.*\)</description>.*:\1:p') 
  echo $name
}

sanitize (){
  local name=$(echo $1 | sed 's/&amp;/_/gi' | sed "s/&apos;/'/gi" | sed 's/[&\\/\?:<>\*\|]/_/g')
  echo $name
}

#$1 check if there were new roms added since last time
###################
checkIfChange (){   
    local ischange=2
	
	now=$(stat -t "$1" | tr -d "$1" | awk '{ print $12 }')
	last=0
	
    if [ ! -f "$1/timestamp" ]; then
        echo $now > "$1/timestamp"
	else
		last=$(cat "$1/timestamp")
    fi
    if [ "$last" != "$now" ]; then
        ischange=1
		echo $now > "$1/timestamp"
    else
        ischange=0
    fi
    echo $ischange  
}

scanarcade () {
	echo -e "    \e[97mScanning $1 for roms...\e[0m" >&2
	#if [ ! -f "$1/roms.crc" ]; then touch "$1/roms.crc"; fi
	unset fullpath
	for fullpath in $1/$2; do
		echo -ne "        \e[94m$fullpath\e[0m" >&2 
		filename=$(basename "$fullpath")
		#crc=$(cksum "$fullpath" | cut -d' ' -f1)
		#if ! grep "$crc $filename" "$1/roms.crc"; then
		#	if ! grep " $filename" "$1/roms.crc"; then
		#		echo "$crc $filename" >> "$1/roms.crc"
		#	else
		#		sed -i "s/^\d+ $filename/$crc $filename/" "$1/roms.crc"
		#	fi
		#else
		#	echo -e " = \033[33mSkipped by CRC\e[0m" >&2
		#	continue
		#fi
		gamename=$(getName ${filename%.*} "$6")
		gamename=$(sanitize "$gamename")
		if [ -z "$gamename" ]; then
			echo -e " = \033[31mNot in $6\e[0m" >&2
			echo $fullpath >> romscanner.unknown
			romsmissing=$((romsmissing+1))
		else
			echo -e " = \033[32m$gamename\e[0m" >&2
			echo $gamename >> romscanner.ok
			echo $fullpath
			echo $gamename
			echo $3
			echo $4
			echo "DETECT"
			echo $5
			romsfound=$((romsfound+1))
		fi  
	done
	if [ -z $fullpath ]; then
	  echo -e "        \e[33mNo roms found\e[0m" >&2
	fi
}

downloadDATs(){
	if [ ! -f $mame_dat ] || [ $p_dats ]; then
		echo "Downloading MAME DAT file..."
		wget -O $mame_dat $mame_dat_url &> /dev/null
		if [ $? -ne 0 ]; then
			echo -e "\033[31mError downloading MAME DAT file. Try to download manually from [$mame_dat_url] and rename it to [$mame_dat]\e[0m"
			rm -f $mame_dat
			exit 1
		fi
	fi
	if [ ! -f $fba_dat ] || [ $p_dats ]; then
		echo "Downloading FBA DAT file..."
		wget -O $fba_dat $fba_dat_url &> /dev/null
		if [ $? -ne 0 ]; then
			echo -e "\033[31mError downloading FBA DAT file. Try to download manually from [$fba_dat_url] and rename it to [$fba_dat]\e[0m"
			rm -f $fba_dat
			exit 1
		fi
	fi
}

thumbnails(){
	mkdir -p "$2/Named_Boxarts" &> /dev/null
	mkdir -p "$2/Named_Snaps" &> /dev/null
	mkdir -p "$2/Named_Titles" &> /dev/null
	
	echo -e "    \e[97mRetrieving roms thumbnails...\e[0m"
	while read p; do
		echo -ne "        \e[94m$p\e[0m"
		result="[Boxart]"
		if [ ! -f "$2/Named_Boxarts/${p}.png" ]; then
			wget -O "$2/Named_Boxarts/${p}.png" "$3/Named_Boxarts/${p// /%20}.png" &> /dev/null
			if [ $? -ne 0 ]; then
				result="\033[31m$result\e[0m"
				thumbsmissing=$((thumbsmissing+1))
			else
				result="\033[32m$result\e[0m"
				thumbsdownloaded=$((thumbsdownloaded+1))
			fi
		fi
		echo -ne " $result"
		result="[Snap]"
		if [ ! -f "$2/Named_Snaps/${p}.png" ]; then
			wget -O "$2/Named_Snaps/${p}.png" "$3/Named_Snaps/${p// /%20}.png" &> /dev/null
			if [ $? -ne 0 ]; then
				result="\033[31m$result\e[0m"
				thumbsmissing=$((thumbsmissing+1))
			else
				result="\033[32m$result\e[0m"
				thumbsdownloaded=$((thumbsdownloaded+1))
			fi
		fi
		echo -ne " $result"
		result="[Title]"
		if [ ! -f "$2/Named_Titles/${p}.png" ]; then
			wget -O "$2/Named_Titles/${p}.png" "$3/Named_Titles/${p// /%20}.png" &> /dev/null
			if [ $? -ne 0 ]; then
				result="\033[31m$result\e[0m"
				thumbsmissing=$((thumbsmissing+1))
			else
				result="\033[32m$result\e[0m"
				thumbsdownloaded=$((thumbsdownloaded+1))
			fi
		fi
		echo -e " $result"
	done <$1
}

summary(){
	echo -e "\e[97mSummary\e[0m"
	echo "    Roms found        : $romsfound"
	echo "    Roms missing      : $romsmissing"
	echo "    Thumbs downloaded : $thumbsdownloaded"
	echo "    Thumbs missing    : $thumbsmissing"
}

version() { echo "romscanner.sh v$VERSION"; }

shortusage() {
	cat << EOF
Usage: romscanner.sh [OPTIONS]
romscanner.sh -h for more information.
EOF
}

usage(){
	cat <<EOF

romscanner.sh [OPTIONS] - Manage Lakka Arcade playlists

This script scans MAME and FBA roms, downloads thumbnails and creates
playlists.

Options:
  -f|--force    force roms rescan
  -d|--dats     force DAT download
  -s|--storage  storage path (default: $storage_path)
  -c|--cores    cores path (default: $cores_path)
  -h|--help     show this help
  -V|--version  print version number

Examples:
  romscanner.sh --force
  romscanner.sh -h
  romscanner.sh -V

Notes:
- If no --force, roms scan will only be performed if a change is detected
  in the roms directories.

- DAT files: http://www.lakka.tv/doc/Arcade/

- Based on https://github.com/libretro/Lakka/issues/344 by fluffymadness

EOF
}

##
## MAIN CODE
##

# Read parameters

while [[ $# -gt 0 ]]; do
	key="$1"
	case $key in
		-d|--dats)
			p_dats=1
			;;
		-f|--force)
			p_force=1
			;;
		-h|--help)
			usage
			exit 0
			;;
		-V|--version)
			version
			exit 0
			;;
		-s|--storage)
			storage_path=$2
			shift
			;;
		-c|--cores)
			cores_path=$2
			shift
			;;
		*)
			shortusage
			exit 1
			;;
	esac
	shift
done

## Fill variables

fillVariables

# Test dirs

if [ ! -d "$roms_path" ]; then echo -e "\e[33m${roms_path} not found!\e[0m"; exit 1; fi
if [ ! -d "$thumbnails_path" ]; then echo -e "\e[33m${thumbnails_path} not found!\e[0m"; exit 1; fi
if [ ! -d "$playlists_path" ]; then echo -e "\e[33m${playlists_path} not found!\e[0m"; exit 1; fi
if [ ! -d "$cores_path" ]; then echo -e "\e[33m${cores_path} not found!\e[0m"; exit 1; fi

# Download DATs files

downloadDATs

# Remove old control files

rm romscanner.unknown -f > /dev/null
rm romscanner.ok -f > /dev/null

# MAME

echo -e "\e[97m${mame_title}\e[0m"
if [ -d "$mame_roms_path" ]; then
	change=$(checkIfChange "$mame_roms_path")
	if [ "$change" -eq "1" ] || [ $p_force ]; then
		rm romscanner.ok -f > /dev/null
		scanarcade "$mame_roms_path" "*.zip" "$mame_cores_path" "$mame_title" "$mame_playlists" "$mame_dat" > "$mame_playlists_path"
		if [ -f romscanner.ok ]; then
			thumbnails "romscanner.ok" "$mame_thumbnails_path" $mame_thumbnails_url
		fi
	else
		echo -e "    \e[33mNo new roms detected\e[0m"
	fi
else
	echo -e "    \e[33m${mame_roms_path} not found!\e[0m"
fi

# FBA

echo -e "\e[97m${fba_title}\e[0m"
if [ -d "$fba_roms_path" ]; then
	change=$(checkIfChange "$fba_roms_path")
	if [ "$change" -eq "1" ] || [ $p_force ]; then
		rm romscanner.ok -f > /dev/null
		scanarcade "$fba_roms_path" "*.zip" "$fba_cores_path" "$fba_title" "$fba_playlists" "$fba_dat" > "$fba_playlists_path"
		if [ -f romscanner.ok ]; then
			thumbnails "romscanner.ok" "$fba_thumbnails_path" $fba_thumbnails_url
		fi
	else
		echo -e "    \e[33mNo new roms detected\e[0m"
	fi
else
	echo -e "    \e[33m${fba_roms_path} not found!\e[0m"
fi

summary

# Remove current control files

rm romscanner.ok -f > /dev/null
