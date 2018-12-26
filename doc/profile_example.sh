# $Id$

# I really want $stage_uri to have a /current/stage3-amd64-latest.tar.xz but they don't do that anymore
stage_uri http://distfiles.gentoo.org/releases/amd64/autobuilds/20181225T214502Z/stage3-amd64-20181225T214502Z.tar.xz
tree_type snapshot https://gentoo.osuosl.org/releases/snapshots/current/portage-latest.tar.xz
rootpw ChangeMe123
bootloader grub

part sda 1 83 100M
part sda 2 82 512M
part sda 3 83 +

format /dev/sda1 ext2
format /dev/sda2 swap
format /dev/sda3 ext3

mountfs /dev/sda1 ext2 /boot
mountfs /dev/sda2 swap
mountfs /dev/sda3 ext3 / noatime

net eth0 dhcp

post_install_portage_tree() {
  cat > ${chroot_dir}/etc/make.conf <<EOF
CHOST="x86_64-pc-linux-gnu"
CFLAGS="-O2 -march=native -pipe"
CXXFLAGS="\${CFLAGS}"
USE="-X -gtk -gnome -kde -qt"
EOF

}
