#!/bin/bash
# Written by Thierry Nuttens
# Copyright Thierry Nuttens 2010-2011-2012-2013-2014
# Installation script for the NuTyX system
# Ce script ne peut être utilisé que pour installer NuTyX

# *********************************************************************
# Variables Definition
# *********************************************************************

if [ -z "${version}" ]; then
	version='saravane'
fi
if [ -z "${URL}" ]; then
	URL='http://downloads.nutyx.org/'
fi
Homepage="${URL}"                ## http://downloads.nutyx.org/
ARCH=`uname -m`                  ## i686
Installbase="$version/$ARCH/"    ## saravane/i686
Package="$Homepage$Installbase"  ## http://downloads.nutyx.org/saravane/i686

Packagebase="$Package/system"    ## http://downloads.nutyx.org/saravane/i686/system

if [ -z "${MountFolder}" ]; then
	MountFolder="/mnt/hd"
fi

Depot="/var/lib/pkg/saravane"
DepotPackages="$Depot/system"
DepotCD="/media/cdrom"


# Size of the FullInstall in Mbytes
let BaseInstall=450

# Number of seconds between STOPSIG and FALLBACK when stopping processes
KILLDELAY="3"

## Screen Dimensions
# Find current screen size

if [ -z "${COLUMNS}" ]; then
        COLUMNS=$(stty size)
        COLUMNS=${COLUMNS##* }
fi

# When using remote connections, such as a serial port, stty size returns 0
if [ "${COLUMNS}" = "0" ]; then
        COLUMNS=80
fi

## Measurements for positioning result messages
COL=$((${COLUMNS} - 8))
WCOL=$((${COL} - 2))

## Provide an echo that supports -e and -n
# If formatting is needed, $ECHO should be used
case "`echo -e -n test`" in
        -[en]*)
                ECHO=/bin/echo
                ;;
        *)
                ECHO=echo
                ;;
esac

## Set Cursor Position Commands, used via $ECHO
SET_COL="\\033[${COL}G"      # at the $COL char
SET_WCOL="\\033[${WCOL}G"    # at the $WCOL char
CURS_UP="\\033[1A\\033[0G"   # Up one line, at the 0'th char

## Set color commands, used via $ECHO
# Please consult `man console_codes for more information
# under the "ECMA-48 Set Graphics Rendition" section
#
# Warning: when switching from a 8bit to a 9bit font,
# the linux console will reinterpret the bold (1;) to
# the top 256 glyphs of the 9bit font.  This does
# not affect framebuffer consoles
NORMAL="\\033[0;39m"         # Standard console grey
SUCCESS="\\033[1;32m"        # Success is green
WARNING="\\033[1;33m"        # Warnings are yellow
FAILURE="\\033[1;31m"        # Failures are red
INFO="\\033[1;36m"           # Information is light cyan
BRACKET="\\033[1;34m"        # Brackets are blue

STRING_LENGTH="0"   # the length of the current message


# ******************************************************************************
# Functions
# ******************************************************************************

#*******************************************************************************
# Function - boot_mesg()
#
# Purpose:      Sending information from bootup scripts to the console
#
# Inputs:       $1 is the message
#               $2 is the colorcode for the console
#
# Outputs:      Standard Output
#
# Dependencies: - sed for parsing strings.
#               - grep for counting string length.
#
# Todo:
#*******************************************************************************
boot_mesg()
{
        local ECHOPARM=""

        while true
        do
                case "${1}" in
                        -n)
                                ECHOPARM=" -n "
                                shift 1
                                ;;
                        -*)
                                echo "Unknown Option: ${1}"
                                return 1
                                ;;
                        *)
                                break
                                ;;
                esac
        done

        ## Figure out the length of what is to be printed to be used
        ## for warning messages.
        STRING_LENGTH=$((${#1} + 1))

        # Print the message to the screen
        ${ECHO} ${ECHOPARM} -e "${2}${1}"

}

boot_mesg_flush()
{
        # Reset STRING_LENGTH for next message
        STRING_LENGTH="0"
}

boot_log()
{
        # Left in for backwards compatibility
        :
}

echo_ok()
{
        ${ECHO} -n -e "${CURS_UP}${SET_COL}${BRACKET}[${SUCCESS}  OK  ${BRACKET}]"
        ${ECHO} -e "${NORMAL}"
        boot_mesg_flush
}
echo_info()
{
        ${ECHO} -n -e "${CURS_UP}${SET_COL}${BRACKET}[${INFO} INFO ${BRACKET}]"
        ${ECHO} -e "${NORMAL}"
        boot_mesg_flush
}

echo_failure()
{
        ${ECHO} -n -e "${CURS_UP}${SET_COL}${BRACKET}[${FAILURE} FAIL ${BRACKET}]"
        ${ECHO} -e "${NORMAL}"
        boot_mesg_flush
}

echo_warning()
{
        ${ECHO} -n -e "${CURS_UP}${SET_COL}${BRACKET}[${WARNING} WARN ${BRACKET}]"
        ${ECHO} -e "${NORMAL}"
        boot_mesg_flush
}

print_error_msg()
{
        echo_failure
	ERREUR="yes"
        # $i is inherited by the rc script
        boot_mesg -n " FAILURE:\n\n You should not read this error.\n\n" ${FAILURE}
        boot_mesg -n " It means something went wrong with the installation"
        boot_mesg -n " of ${i} "
	boot_mesg -n " The output error is: ${error_value}.\n"
        boot_mesg_flush
        boot_mesg -n " Tanks to inform us"
        boot_mesg -n " via the website http://www.nutyx.org."
        boot_mesg " Tanks again for your collaboration.\n"
        boot_mesg_flush
        boot_mesg -n "Press Enter to continue..." ${INFO}
        boot_mesg "" ${NORMAL}
        read ENTER
        end
	exit 1
}


#*******************************************************************************
# Function - log_success_msg "message"
#
# Purpose: Print a success message
#
# Inputs: $@ - Message
#
# Outputs: Text output to screen
#
# Dependencies: echo
#
# Todo: logging
#
#*******************************************************************************
log_success_msg()
{
        ${ECHO} -n -e "${BOOTMESG_PREFIX}${@}"
        ${ECHO} -e "${SET_COL}""${BRACKET}""[""${SUCCESS}""  OK
""${BRACKET}""]""${NORMAL}"
        return 0
}

#*******************************************************************************
# Function - log_failure_msg "message"
#
# Purpose: Print a failure message
#
# Inputs: $@ - Message
#
# Outputs: Text output to screen
#
# Dependencies: echo
#
# Todo: logging
#
#*******************************************************************************
log_failure_msg() {
        ${ECHO} -n -e "${BOOTMESG_PREFIX}${@}"
        ${ECHO} -e "${SET_COL}""${BRACKET}""[""${FAILURE}"" FAIL
""${BRACKET}""]""${NORMAL}"
        return 0
}

#*******************************************************************************
# Function - log_warning_msg "message"
#
# Purpose: print a warning message
#
# Inputs: $@ - Message
#
# Outputs: Text output to screen
#
# Dependencies: echo
#
# Todo: logging
#
#*******************************************************************************
log_warning_msg() {
        ${ECHO} -n -e "${BOOTMESG_PREFIX}${@}"
        ${ECHO} -e "${SET_COL}""${BRACKET}""[""${WARNING}"" WARN
""${BRACKET}""]""${NORMAL}"
        return 0
}
#*******************************************************************************
# Function - unmountall
#
# Purpose:	unmount all the mounted disks and partitions
#
# Inputs:	$1 the full path of the Distro
#
# Outputs:	Standard Output
#
# Dependencies: chroot
#
#*******************************************************************************
unmountall() {
# if [ $# -lt 1 ]; then 
#	echo 1>&2 
#	echo 1>&2 'Usage: unmountall point de montage (/arch par exemple)'
#	exit 1
# fi
if [ -d "$DepotCD/depot" ]; then
	umount ${1}/${Depot}
	umount  `cat /tmp/depot`
fi
umount ${1}/dev/shm
umount ${1}/dev/pts
umount ${1}/dev
umount ${1}/tmp 
umount ${1}/proc 
umount ${1}/sys
}
#*******************************************************************************
# Function - setup_chroot
#
# Purpose:	Enter the NuTyX Distribution
#
# Inputs:	$1 the full path of the Distro
#
# Outputs:	Standard Output
#
# Dependencies: chroot
#
#*******************************************************************************
setup_chroot() {
mount --bind /dev ${1}/dev
mount -t devpts devpts ${1}/dev/pts
mount -t proc proc ${1}/proc 
mount -t sysfs sysfs ${1}/sys
chroot ${1} /bin/bash -c "$SetupFile"
}
#*******************************************************************************
# Function - install_pkg()
#
# Purpose:      Install the selected package
#
# Inputs:       $1 is the package
#               $2 is the group
#		$3 Option to install, normally nothing except for grub
# Outputs:      Standard Output
#
# Dependencies: - wget
#               - boot_mesg
#               - pkgadd
# Todo:
#*******************************************************************************
install_pkg() {
if $TMP/usr/bin/pkginfo -r $MountFolder -i| grep "^$1 " > /dev/null; then
	boot_mesg "$1 is already install on $DEVICE..."
	echo_info
else
	packagefileToDownload=`getPackageName ${1}`
	boot_mesg "Downloading $1..."
	wget $Packagebase/${1}/$packagefileToDownload  -O $TMP/$packagefileToDownload > /dev/null 2>&1
	echo_info
	# Installing the package
	$TMP/usr/bin/pkgadd -r $MountFolder $packagefileToDownload || print_error_msg
	echo_ok	
fi
}

#*******************************************************************************
# Function Check_DiskSpace
#
# Purpose:      Check the Available space after the using amont

# Inputs:       $1: Mount point
#	        $2: Amount in Kbytes going to be used
#
# Return:       status: 0 when ok
#	                1 not ok
# Todo:
#*******************************************************************************
Check_DiskSpace() {
	# df|grep "$1"|awk '{print $4}'
	let MinSize=$2+100
	let Amoung=`df|grep $MountFolder |awk '{print $(NF-2)}'`/1024
	let Amoung=$Amoung-$MinSize
	
	status="0"
	if [ $Amoung -lt 0 ]; then
		echo "Not enough space for the installation"
		echo_failure
		status="1"
	else
		echo "Space remind after install: $Amoung Mbytes"
		echo_info
	fi
}

#*******************************************************************************
# Function DiskSpace
#
# Purpose:      Printout the Available space on the Mount point
#
# Inputs:       $1: Mount point
#
# Output:       Standard Output
#
# Todo:
#*******************************************************************************
DiskSpace() {
	let TotAmoung=`df|grep "$1"|awk '{print $4}'`/1024
	echo "You have at the moment: ${TotAmoung} Mbytes on the destination disk"
}


error() {
echo "***********************************************"
echo ""
echo " $1"
echo ""
echo "***********************************************"
rm -rf $TMP
exit 1
}

end() {
if [ "$ERREUR" == "yes" ]; then
	if [ ! -f $TMP/depot ]; then
		rm -r ${MountFolder}/${Depot}
		boot_mesg "Cleaning up temporary files.."
		boot_mesg "Please correct and start again"
	fi
fi
cd ~
unmountall $MountFolder > /dev/null 2>&1

if [ "$MIG" == "0" ]; then
  umount $MountFolder > /dev/null 2>&1
fi
rm -rf $TMP
}
#****************************************************************************
# Function expect
# 
# Purpose:	Check that the answer is nothing else then the supply
#		arguments
# Inputs:	$1: answer 1
#		$2: answer 2
#		$3: The question to ask
#
# Output:	Standard Output
#
#****************************************************************************
expect(){
# echo -n "$3"
# read answer
while [ "$answer" != "o" ] && [ "$answer" != "n" ]; do
	echo -n "$3"
	read answer
done
}

#****************************************************************************
# Function getPackageName
# 
# Purpose:	Get the fullname of the package
#		directory
# Inputs:	$1 is the package name
#
# Output:       fullname of the archive without url
#               something like: cpio1414074943i686.cards.tar.xz
#****************************************************************************

getPackageName()
{
local BUILD_DATE EXT HEAD
wget $Packagebase/${1}/MD5SUM  -O $TMP/MD5SUM > /dev/null  2>&1

HEAD=`head -1 $TMP/MD5SUM`
if [ "${HEAD:10:1}" == ":" ]; then
	BUILD_DATE="`echo $HEAD|cut -d ":" -f1`"
	EXT="`echo $HEAD|cut -d ":" -f2`"
	echo "${1}${BUILD_DATE}${ARCH}${EXT}"
fi
}

install_base()
{
for i in \
aaabasicfs acl attr bash bc binutils bzip2 coreutils cpio curl \
dhcpcd diffutils e2fsprogs e3 eudev expat file findutils flex gcc gdbm \
gettext glibc gmp gperf grep grub gzip dialog mdadm \
iana-etc inetutils iproute2 kbd kmod \
libarchive libcap libpipeline lvm2 mpc mpfr ncurses openssl pam \
procps-ng psmisc readline lzo \
reiserfsprogs sed shadow squashfs sudo \
sysklogd sysvinit tar tzdata util-linux xfsprogs xz zlib \
cards ca-certificates
do 
	install_pkg "$i"
done

}
# *****************************************************************************************************
# Begin of Installer
# *****************************************************************************************************

# Checking if we use the right interpreter
if ! (bash --version >/dev/null 2>&1)  then
	error " Wrong interpreter, please use bash as interpreter"
fi

# On a disk or in a Folder
MIG=`echo $1|cut -d "/" -f 2`
# echo $MIG
if [ "$MIG" == "dev" ]; then
	MIG=0  # Disk
else
	MountFolder=$1 
	MIG=1
	echo "This installation will be on $1"
	echo_info
fi
DEVICE=$1

# Welcome

                        echo "*******************************************"
if [ "$MIG" == "0" ]; then
	if [ ! -z "${KEYMAP}" ] || [ -f /etc/sysconfig/console ]; then
		if [ $# -lt 2 ]; then
			echo "* You didn't specify enough arguments     *"
			echo "* Argument 1: Destination partition       *"
			echo "* Argument 2: Filesystem to be used       *"
			echo "*                                         *"	
			echo "* Please re-enter the command with the    *"
			echo "* corrects arguments                      *"
			echo "*******************************************"
			echo ""
			echo "example: install-$version.ash /dev/sda1 ext3"

			exit 1
		fi
		if [ ! -z "${KEYMAP}" ]; then
			clavier=$KEYMAP
		else
			clavier=`grep "^KEYMAP" /etc/sysconfig/console|sed 's/KEYMAP=//'|sed 's/.map//'`
		fi
	else
		if [ $# -lt 3 ]; then
			echo "* You didn't specify enough arguments     *"
			echo "* Argument 1: Destination partition       *"
			echo "* Argument 2: Filesystem to be used       *"
			echo "* Argument 3: Keyboard layout             *"
			echo "*                                         *"
			echo "* Please re-enter the command with the    *"
			echo "* corrects arguments                      *"	
			echo "*******************************************"
			echo ""
			echo "example: install-$version.ash /dev/sda1 ext4 fr-latin1"
			exit 1
		fi
		clavier=$3
	fi
	echo "Le système de fichier sera $2"
	echo_info
	FILESYSTEM=$2
else
	if [ ! -z "${KEYMAP}" ] || [ -f /etc/sysconfig/console ]; then
		clavier=`grep "^KEYMAP" /etc/sysconfig/console|sed 's/KEYMAP=//'|sed 's/.map//'`
		if [ $# -lt 1 ]; then
                        echo "* You didn't specify enough arguments     *"
                        echo "* Argument 1: Folder destionation         *"
                        echo "*                                         *"
                        echo "* Please re-enter the command with the    *"
                        echo "* corrects arguments                      *"
                        echo "*******************************************"
                        echo ""
			echo "example: install-$version.ash /chroot"
                        exit 1
		fi
		if [ ! -z "${KEYMAP}" ]; then
                        clavier=$KEYMAP
                else
                        clavier=`grep "^KEYMAP" /etc/sysconfig/console|sed 's/KEYMAP=//'|sed 's/.map//'`
                fi
	else
                if [ $# -lt 2 ]; then
                        echo "* You didn't specify enough arguments     *"
                        echo "* Argument 1: Folder destionation         *"
                        echo "* Argument 2: Keyboard layout             *"
                        echo "*                                         *"
                        echo "* Please re-enter the command with the    *"
                        echo "* corrects arguments                      *"
                        echo "*******************************************"
                        echo ""
                        echo "example: install-$version.ash /chroot fr-latin1"
                        exit 1
		fi
		clavier=$2
	fi	
fi
TMP=`mktemp -d`
echo $clavier > $TMP/locale.check

CLAVIER=$clavier

# Checking the MountFolder
if ! [ -d $MountFolder ]; then
	mkdir -p $MountFolder
fi
# Checking the Mount point
if [ "$MIG" == "0" ]; then
	# Checking the device exist ?
	if ! [ -b  $1 ]; then
		error "Mounting point $1 not existing"
		exit 0
	fi
	# Mounting the System files
	if ! mountpoint /$MountFolder > /dev/null; then
		mount -t $FILESYSTEM $1 $MountFolder || error "Invalid partition or wrong format"
	fi
	# Check available space
	Check_DiskSpace $1 $BaseInstall
	if [ $status == "1" ]; then
		DiskSpace $1 
		echo "The installation needs $BaseInstall Mbytes minimum"
		end
		exit 1
	fi
	
fi
# Création du dossier des dépots
if ! [ -d ${MountFolder}${DepotPackages} ]; then
	mkdir -p ${MountFolder}${DepotPackages}

fi

pkgconf="fail"
error_value=101
if [ ! -f $TMP/usr/bin/pkgadd ]; then
	# Getting cards.devel
	cd $TMP
	basepackagefile=`getPackageName cards`
	if [ "$basepackagefile" == "" ]; then
		error "$basepackagefile not found"
		exit 0
	fi
	packagefile=`echo ${basepackagefile}|sed "s|^cards|cards.devel|"`
	echo "Downloads of $packagefile"
	if  [ ! -f ${packagefile} ]; then
		wget $Packagebase/cards/$packagefile || print_error_msg
		echo_ok
	fi
	echo "Extraction of cards.devel ..."
	tar -xf ${packagefile} || print_error_msg
	echo_ok

fi
if [ ! -d ${MountFolder}/var/lib/pkg/DB ]; then
	mkdir -p ${MountFolder}/var/lib/pkg/DB
fi
install_base

# replace in cards with the correct arch
sed -i "s|latest|${ARCH}|" ${MountFolder}/etc/cards.conf

if [ "$MIG" == "0" ]; then
	echo "$1     /    $2    defaults   0   1" >> ${MountFolder}/etc/fstab  
fi
if [ -f /etc/resolv.conf ]; then
	cp /etc/resolv.conf ${MountFolder}/etc
fi
# Exit and unmounting all
end
if [ "$MIG" == "0" ]; then
	if [ -f $TMP/depot ]; then
		umount  ${MountFolder}${DepotPackages} > /dev/null 2>&1
		umount  ${MountFolder}${DepotCD} > /dev/null 2>&1
	fi
fi
echo "***************************************************"
echo "* Installation finish. Tanks for installing NuTyX *"
echo "*                                                 *"
echo "* Dont forget to choose a valid kernel before you *"
echo "*      want to boot on your install NuTyX         *"
echo "*                                                 *"
echo "*        For more info, come to visit us:         *"
echo "*                                                 *"
echo "*              http://www.nutyx.org               *"
echo "*                                                 *"
echo "***************************************************"
echo ""
