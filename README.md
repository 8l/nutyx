# nutyx
http://nutyx.org

http://nutyx.org/en/generate-iso.html

 Produce a customised ISO
[NOTE IMPORTANTE]All the commands should be enter in the root account

    Get all the tools

    git clone git://git.tuxfamily.org/gitroot/nutyx/saravane.git
    wget http://downloads.nutyx.org/EnterChroot
    wget http://downloads.nutyx.org/install-saravane.ash

    Make shure you have cdrkit and syslinux installed, in worth case:

    get cdrkit
    get syslinux

    A variable will be used during the all process

    The LFS variable MUST be defined

    export LFS=/ISO-MINI

    The chroot will be in the "/ISO-MINI" directory. Up to you to choose another place.
    Install the base somewhere

    sh install-saravane.ash $LFS

    Copy the files for the iso

    cp -av saravane/iso $LFS/ISO

    Enter the base

    sh EnterChroot

    Optionnal: if you have everything on your local host

    sed -i "s@downloads.nutyx.org@localhost@" etc/cards.conf

    Create the directories and get the meta datas

    mkdir -p /usr/ports/desktop
    mkdir -p /usr/ports/console
    cards sync

    Install a kernel

    get kernel

    ou

    get kernel-lts

    Put the kernel and the initrd in the right place

    cp -v /boot/kernel-* /ISO/isolinux/kernel
    cp -v /boot/initrd-* /ISO/isolinux/initrd

    Optionnal: Reset the default adress of the NuTyX mirror

    sed -i "s@localhost@downloads.nutyx.org@" etc/cards.conf

    Flush the binaries archives

    find /var/lib/pkg/saravane/ -name "*.cards.*" -exec rm -v {} \;

    Generate the squashfs files

    mkdir -p /ISO/isolinux/boot/
    cd /
    for dir in opt bin etc lib root run sbin usr var home
    do
      [ -f ISO/isolinux/boot/$dir.squashfs ] && rm ISO/isolinux/boot/$dir.squashfs
      mksquashfs $dir ISO/isolinux/boot/$dir.squashfs
    done

    Quit the NuTyX chroot

    exit

    Generate the ISO

    sh saravane/scripts/mkiso saravane-`date +%Y%m%d`

    Conclusion

    The size shoul'nd be bigger then 150 MB if you didn't put anything else then a kernel as extra package. You will find the iso in the $LFS directory.

    ls $LFS

    bin   dev  home  lib  NuTyX_i686-saravane-20150331.iso     proc  run   srv  tmp  var
    boot  etc  ISO   mnt  NuTyX_i686-saravane-20150331.md5sum  root  sbin  sys  usr

