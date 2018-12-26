# $Id$

sanity_check_config_bootloader() {
  if [ -z "${bootloader}" ]; then
    warn "bootloader not set...assuming grub"
    bootloader="grub"
  fi
}

configure_bootloader_grub() {
  echo -e "default 0\ntimeout 30\n" > ${chroot_dir}/boot/grub/grub.conf
  local boot_root="$(get_boot_and_root)"
  local boot="$(echo ${boot_root} | cut -d '|' -f1)"
  local boot_device="$(get_device_and_partition_from_devnode ${boot} | cut -d '|' -f1)"
  local boot_minor="$(get_device_and_partition_from_devnode ${boot} | cut -d '|' -f2)"
  local root="$(echo ${boot_root} | cut -d '|' -f2)"
  local kernel_initrd="$(get_kernel_and_initrd)"

  # Clear out any existing device.map for a "clean" start
  rm ${chroot_dir}/boot/grub/device.map &>/dev/null

  for k in ${kernel_initrd}; do
    local kernel="$(echo ${k} | cut -d '|' -f1)"
    local initrd="$(echo ${k} | cut -d '|' -f2)"
    local kv="$(echo ${kernel} | sed -e 's:^kernel-genkernel-[^-]\+-::')"
    echo "title=Gentoo Linux ${kv}" >> ${chroot_dir}/boot/grub/grub.conf
    local grub_device="$(map_device_to_grub_device ${boot_device})"
    if [ -z "${grub_device}" ]; then
      error "could not map boot device ${boot_device} to grub device"
      return 1
    fi
    echo -en "root (${grub_device},$(expr ${boot_minor} - 1))\nkernel /boot/${kernel} " >> ${chroot_dir}/boot/grub/grub.conf
    if [ -z "${initrd}" ]; then
      echo "root=${root}" >> ${chroot_dir}/boot/grub/grub.conf
    else
      echo "root=/dev/ram0 init=/linuxrc ramdisk=8192 real_root=${root} ${bootloader_kernel_args}" >> ${chroot_dir}/boot/grub/grub.conf
      echo -e "initrd /boot/${initrd}\n" >> ${chroot_dir}/boot/grub/grub.conf
    fi
  done
  if ! spawn_chroot "grep -v rootfs /proc/mounts > /etc/mtab"; then
    error "could not copy /proc/mounts to /etc/mtab"
    return 1
  fi
  [ -z "${bootloader_install_device}" ] && bootloader_install_device="$(get_device_and_partition_from_devnode ${boot} | cut -d '|' -f1)"
  if ! spawn_chroot "grub-install ${bootloader_install_device}"; then
    error "could not install grub to ${bootloader_install_device}"
    return 1
  fi
}

configure_bootloader_grub2() {
    debug configure_bootloader_grub2 "configuring and deploying grub2"

    check_chroot_fstab /boot && spawn_chroot "[ -z \"\$(mount | grep /boot)\" ] && mount /boot"            

    [ -z "${!grub2_install[@]}" ] && warn "looks like it's pulling grub:2 but 'grub2_install' is not set... is it intended?"
    for device in "${!grub2_install[@]}"; do
        # FIXME only accepts a single option currently (--modules=)        
        local key=$(echo ${grub2_install["${device}"]} | cut -d'=' -f1)
        local value=$(echo ${grub2_install["${device}"]} | cut -d'=' -f2)
    
        if [ -n "${key}" ] && [ -n "${value}" ]; then 
            debug configure_bootloader_grub2 "deploying grub2-install $key=$value /dev/${device}"
            spawn_chroot "grub2-install ${key}=${value} /dev/${device}" || die "Could not deploy grub2-install $key=$value /dev/${device}"
        else
            debug configure_bootloader_grub2 "deploying grub2-install /dev/${device}"
            spawn_chroot "grub2-install /dev/${device}" || die "Could not deploy grub2-install /dev/${device}"
        fi
        #spawn_chroot "grub2-install --modules=\"part_gpt mdraid1x lvm xfs\" /dev/sda" || die "Could not deploy with grub2-install on /dev/sda"
        #spawn_chroot "grub2-install --modules=\"part_gpt mdraid1x lvm xfs\" /dev/sdb" || die "Could not deploy with grub2-install on /dev/sdb"
    done
    
    if [ -n "${bootloader_kernel_args}" ]; then
        local args=$(echo ${bootloader_kernel_args} | \
        sed -e 's:{{root_keydev_uuid}}:$(get_uuid ${luks_remdev}):' | \
        sed -e 's:{{root_key}}:${luks_key}:')
        debug configure_bootloader_grub2 "GRUB_CMDLINE_LINUX=$(echo ${args}) to /etc/default/grub"
	spawn "cp -f ${chroot_dir}/etc/default/grub ${chroot_dir}/etc/default/grub.example" || die "Could not copy ${chroot_dir}/etc/default/grub to ${chroot_dir}/etc/default/grub.example"
	spawn "cat ${chroot_dir}/etc/default/grub.example | grep -v ^#.* > ${chroot_dir}/etc/default/grub" || die "Could not filter comments out from ${chroot_dir}/etc/default/grub"
	spawn "echo -e '\n\nGRUB_CMDLINE_LINUX=\"\$GRUB_CMDLINE_LINUX ${args}\"' >> ${chroot_dir}/etc/default/grub" || die "Could not add dolvm option to ${chroot_dir}/etc/default/grub"
    fi
    debug configure_grub2 "generating /boot/grub/grub.cfg"
    spawn_chroot "grub2-mkconfig -o /boot/grub/grub.cfg" || die "Could not generate /boot/grub2/grub.cfg"
}
