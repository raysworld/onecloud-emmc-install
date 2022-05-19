# OneCloud eMMC installation script

This repository helps you with the installation of the latest Armbian image to the eMMC partition of a Xunlei OneCloud device. Tested with OneCloud hardware version v1.0.

# How to use
Before you start, please make sure you have met all the following requirements:

1. You have installed [aml_burn_tool](https://androidmtk.com/download-amlogic-usb-burning-tool) and know how to use it.
2. You have flashed `s805_flash_snail.img` to your OneCloud device. You may download from [here](https://url03.ctfile.com/f/15483003-581309920-5e8a2b?p=2091) (PW：2091).
3. You have a usb2ttl converter and can get the tty output work via Putty.

## Pre-steps before Image Compilation

Thanks to [hzyitc](https://github.com/hzyitc), the official repository of armbian has now add support for OneCloud (see [this link](https://github.com/armbian/build/commit/965ce372de88a9330769a41a7f169e64e5c263df)). You may now build the official image for OneCloud.

To make the image boot, several modifications are needed (see [here](https://github.com/armbian/build/commit/d056d28ccb0a3fcfd6494552132586e44bd36fb5)):
1. Add `boot-onecloud.cmd` script at `/<armbian_src>/config/bootscripts/boot-onecloud.cmd`;
2. Modify `meson_common.inc` at `/<armbian_src>/config/sources/families/include/meson_common.inc`;
3. Add `onecloud.txt` at `/<armbian_src>/config/bootenv/onecloud.txt`;

## Post-steps after Image Compilation

1. After the modification, build the image and burn the image to a USB stick with your preferred tool (e.g. rufus).

2. Insert the USB stick to your PC and mount the boot partition, and copy the whole folder to the boot partition. Then your file tree should look like:
   ```
   |--install
   |  |--mkfs
   |  |  |--mkfs.fat
   |  |  |--mkfs.msdoc
   |  |  |--mkfs.vfat
   |  |--install.sh
   |  |--...
   |--armbianEnv.txt
   |--boot.cmd
   |--boot.scr
   |--...
   ```

3. Now your USB stick should be ready to go.

## Prepare your bootloader

1. If you have flashed `s805_flash_snail.img`, then your u-boot will try to boot by locating `s805_autoscript` from any connected device (usb/mmc). 
 
2. You may check the u-boot scripts with the following steps:
   
   1. Jump into the u-boot by hitting `enter` after plugging the power cable.
   2. Type `print` in the u-boot console.

3. Type the following lines one by one to make the u-boot adapt to the new boot format (lines that start with `#` are comments and should be ignored):
   ```bash
    setenv bootfromrecovery 0
    setenv bootfromnand 0

    # set a script called start_mmc_autoscript, which tries to load boot.scr from mmc 0 first, if failed, then from mmc 1
    setenv start_mmc_autoscript 'if fatload mmc 0 11000000 boot.scr; then autoscr 11000000; fi; if fatload mmc 1 11000000 boot.scr; then autoscr 11000000; fi;'

    # set a script called start_usb_autoscript, which tries to load boot.scr from usb 0 first, if failed, then from usb 1
    setenv start_usb_autoscript "if fatload usb 0 11000000 boot.scr; then autoscr 11000000; fi; if fatload usb 1 11000000 boot.scr; then autoscr 11000000; fi;"
    
    # set a script called start_autoscript, which checks if any usb device is connected. If so, call start_usb_autoscript; otherwise, call start_mmc_autoscript
    setenv start_autoscript 'if usb start; then run start_usb_autoscript; fi; if mmcinfo 1; then run start_mmc_autoscript; fi;'

    setenv bootcmd 'run start_autoscript; run storeboot'
    setenv firstboot 1

    saveenv
   ```
4. Now your u-boot should be ready to go. Insert your USB stick to the OneCloud and type `reset` to restart. Your device should be able to boot from the USB stick. After logging, navigate to /boot/install, and run
   ```bash
   ./install.sh
   ```
   You will be notified to restart when finished.
5. Unplug your USB stick and restart the system. Now the OS has been installed to your eMMC. Enjoy!  

