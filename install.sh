#!/bin/sh
MAC=""
PATH=${PATH}:/boot/install/mkfs

echo "Installing Armbian OS to the eMMC... Please wait..."

INSTALL_PATH=/boot/install

#sh ${INSTALL_PATH}/update_led.sh &
if [ -e /dev/mmcblk0 ];then
    DEV=mmcblk0
else
    DEV=mmcblk1
fi

DEV_EMMC=/dev/${DEV}
DEV_BOOT0=${DEV_EMMC}boot0
DEV_BOOT1=${DEV_EMMC}boot1
# BOOT0=${DEV}boot0
# BOOT1=${DEV}boot1
PART_BOOT=${DEV_EMMC}p1
PART_ROOT=${DEV_EMMC}p2
# UBOOT=${INSTALL_PATH}/u-boot.bin
# ENV=${INSTALL_PATH}/env.img

rm -f /etc/machine-id
systemd-machine-id-setup

if [ -z "$MAC" ]; then
	MAC=$(dd if=/dev/urandom bs=1024 count=1 2>/dev/null | md5sum | sed -e 's/^\(..\)\(..\)\(..\)\(..\).*$/00:22:\1:\2:\3:\4/' -e 's/^\(.\)[13579bdf]/\10/')
	
	[ -f /opt/client.crt ] && {
	    MAC=$(openssl x509 -in /opt/client.crt -noout --text | grep "Subject:" | awk '{print $10}' | awk -F '[' '{print $2}' | awk -F ']' '{print $1}') 
	}
fi
echo "MAC: ${MAC} created."

echo "Creating MBR and partittion..."

parted -s "${DEV_EMMC}" mklabel msdos
parted -s "${DEV_EMMC}" mkpart primary fat32 108M 620M
parted -s "${DEV_EMMC}" mkpart primary ext4  724M 100%

# echo "Start restore u-boot"

# dd if=${UBOOT} of="${DEV_EMMC}" conv=fsync bs=1 count=442
# dd if=${UBOOT} of="${DEV_EMMC}" conv=fsync bs=512 skip=1 seek=1
# dd if=${ENV} of="${DEV_EMMC}" conv=fsync bs=1M seek=628 count=8

sync
echo "Done"

echo "Copying system files to the eMMC..."

mkdir -p /ddbr
chmod 777 /ddbr

DIR_INSTALL="/ddbr/install"

if [ -d $DIR_INSTALL ] ; then
    rm -rf $DIR_INSTALL
fi
mkdir -p $DIR_INSTALL

if grep -q $PART_BOOT /proc/mounts ; then
    echo "Unmounting BOOT partiton."
    umount -f $PART_BOOT
fi
echo -n "Formatting BOOT partition..."
mkfs.vfat -n "BOOT_EMMC" $PART_BOOT
echo "done."

mount -o rw $PART_BOOT $DIR_INSTALL

echo -n "Copying BOOT..."
cp -r /boot/* $DIR_INSTALL 
sync
echo "done."

echo -n "Modifying armbianEnv.txt and boot.scr..."
emmcuuid=$(blkid -o export ${PART_ROOT} | grep -w UUID)
echo -n "ROOT partition UUID: ${emmcuuid}"
if [ -f "${DIR_INSTALL}"/armbianEnv.txt ]; then
    sed -e 's,rootdev=.*,rootdev='"${PART_ROOT}"',g' -i "${DIR_INSTALL}"/armbianEnv.txt
    #grep -q '^rootdev' "${DIR_INSTALL}"/armbianEnv.txt || echo "rootdev=$emmcuuid" >> "${DIR_INSTALL}"/armbianEnv.txt
fi
if [ -f "${DIR_INSTALL}"/boot.cmd ]; then
    sed -e 's,setenv rootdev.*,setenv rootdev "${PART_ROOT}",' -i "${DIR_INSTALL}"/boot.cmd
    sed -e 's,setenv bootdev.*,setenv bootdev "mmc 1",' -i "${DIR_INSTALL}"/boot.cmd
fi
mkimage -C none -A arm -T script -d "${DIR_INSTALL}"/boot.cmd "${DIR_INSTALL}"/boot.scr
echo "done."

umount $DIR_INSTALL

if grep -q $PART_ROOT /proc/mounts ; then
    echo "Unmounting ROOT partiton."
    umount -f $PART_ROOT
fi

echo "Formatting ROOT partition..."
mke2fs -F -q -t ext4 -L ROOT_EMMC -m 0 $PART_ROOT
e2fsck -n $PART_ROOT
echo "done."

echo "Copying ROOTFS."
mount -o rw $PART_ROOT $DIR_INSTALL

cd /
echo "Copying BIN..."
tar -cf - bin | (cd $DIR_INSTALL; tar -xpf -)
#echo "Copy BOOT"
#mkdir -p $DIR_INSTALL/boot
#tar -cf - boot | (cd $DIR_INSTALL; tar -xpf -)
echo "Creating DEV..."
mkdir -p $DIR_INSTALL/dev
#tar -cf - dev | (cd $DIR_INSTALL; tar -xpf -)
echo "Copying ETC..."
tar -cf - etc | (cd $DIR_INSTALL; tar -xpf -)
echo "Copying HOME..."
tar -cf - home | (cd $DIR_INSTALL; tar -xpf -)
echo "Copying LIB..."
tar -cf - lib | (cd $DIR_INSTALL; tar -xpf -)
echo "Creating MEDIA..."
mkdir -p $DIR_INSTALL/media
#tar -cf - media | (cd $DIR_INSTALL; tar -xpf -)
echo "Creating MNT..."
mkdir -p $DIR_INSTALL/mnt
#tar -cf - mnt | (cd $DIR_INSTALL; tar -xpf -)
echo "Copying OPT..."
tar -cf - opt | (cd $DIR_INSTALL; tar -xpf -)
echo "Creating PROC..."
mkdir -p $DIR_INSTALL/proc
echo "Copying ROOT..."
tar -cf - root | (cd $DIR_INSTALL; tar -xpf -)
echo "Creating RUN..."
mkdir -p $DIR_INSTALL/run
echo "Copying SBIN..."
tar -cf - sbin | (cd $DIR_INSTALL; tar -xpf -)
echo "Copying SELINUX..."
tar -cf - selinux | (cd $DIR_INSTALL; tar -xpf -)
echo "Copying SRV..."
tar -cf - srv | (cd $DIR_INSTALL; tar -xpf -)
echo "Creating SYS..."
mkdir -p $DIR_INSTALL/sys
echo "Creating TMP..."
mkdir -p $DIR_INSTALL/tmp
echo "Copying USR..."
tar -cf - usr | (cd $DIR_INSTALL; tar -xpf -)
echo "Copying VAR..."
tar -cf - var | (cd $DIR_INSTALL; tar -xpf -)

echo "Copying fstab..."
rm $DIR_INSTALL/etc/fstab
cp -a ${INSTALL_PATH}/fstab $DIR_INSTALL/etc/fstab

echo "Changing MAC..."
cp -p $DIR_INSTALL/etc/network/interfaces.default $DIR_INSTALL/etc/network/interfaces
sed -i '/iface eth0 inet dhcp/a\hwaddress '${MAC} $DIR_INSTALL/etc/network/interfaces

cd /
sync

umount $DIR_INSTALL

echo "*******************************************"
echo " Armbian has been installed to eMMC. Now   "
echo " you may un-plug the power cable to reboot."
echo "*******************************************"
