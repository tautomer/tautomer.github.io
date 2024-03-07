---
layout: post_markdown
title: Enlarge the system partition of my Debian VM
description: A tutorial to resize the system partition of a virtual machine
tags:
- Home Lab
- Self-hosted
- Proxmox
---
# Enlarge the system partition of my Debian VM

Long story short, my docker containers on the Debian VM is taking up too much
space. Instead of cleaning things up, I decided to give it more space. The thing
is that increasing the disk size from the Proxmox side will not directly result
in a large partition in the VM, because it will not automatically allocate the
space. Here is what we have to do manually.

Note that even though this is for a KVM, it should work for bare-metal as well.

Also note if you regret assigning more disk space to the VM, you are (probably)
out of luck with a `zfspool` (exactly my case). If you are having an `.img` or
`.qcow2` virtual disk, you can use `qemu-img` to shrink the disk.


## Procedure

1. Turn off swap with `sudo swapoff -a` and you will know why we do this in one
   second.
   
2. Run `sudo fdisk /dev/sda`. `/dev/sda` should be the drive you want to work
   on. You will see the following output

   ```console
   Welcome to fdisk (util-linux 2.38.1).
   Changes will remain in memory only, until you decide to write them.
   Be careful before using the write command.
   
   This disk is currently in use - repartitioning is probably a bad idea.
   It's recommended to umount all file systems, and swapoff all swap
   partitions on this disk.
   
   
   Command (m for help):
   ```

3. Print all partitions with command `p`

   ```console
   Command (m for help): p

   Disk /dev/sda: 70 GiB, 75161927680 bytes, 146800640 sectors
   Disk model: QEMU HARDDISK
   Units: sectors of 1 * 512 = 512 bytes
   Sector size (logical/physical): 512 bytes / 512 bytes
   I/O size (minimum/optimal): 512 bytes / 512 bytes
   Disklabel type: dos
   Disk identifier: 0xf9687e2f

   Device     Boot     Start       End   Sectors  Size Id Type
   /dev/sda1  *         2048 102856703 102854656   49G 83 Linux
   /dev/sda2       102858750 104855551   1996802  975M  5 Extended
   /dev/sda5       102858752 104855551   1996800  975M 82 Linux swap / Solaris
   ```

   Print the free space with `F`

   ```console
   Command (m for help): F
   Unpartitioned space /dev/sda: 20.95 GiB, 22499295232 bytes, 43943936 sectors
   Units: sectors of 1 * 512 = 512 bytes
   Sector size (logical/physical): 512 bytes / 512 bytes

       Start       End  Sectors Size
   104855552 146800639 41947134  20G
   ```

   Based on the output, the disk partitions are like this. `/dev/sda1` is the OS
   partition, followed by an extended partition `/dev/sda2` with one logical
   partition `/dev/sda5`. The 20 GB free space is behind the the extended
   partition.

   Without manipulating `/dev/sda2`, we cannot merge the free space with the OS
   partition. Luckily, `dev/sda2` has only one partition, `/dev/sda5`, which is
   the swap partition, and we have turned swap off already, so we can safely
   remove `/dev/sda2`.
   
4. Remove the swap partition with commend `d`

   ```console

   Command (m for help): d
   Partition number (1,2,5, default 5): 2

   Partition 2 has been deleted.

   Command (m for help): p
   Disk /dev/sda: 70 GiB, 75161927680 bytes, 146800640 sectors
   Disk model: QEMU HARDDISK
   Units: sectors of 1 * 512 = 512 bytes
   Sector size (logical/physical): 512 bytes / 512 bytes
   I/O size (minimum/optimal): 512 bytes / 512 bytes
   Disklabel type: dos
   Disk identifier: 0xf9687e2f

   Device     Boot Start       End   Sectors Size Id Type
   /dev/sda1  *     2048 102856703 102854656  49G 83 Linux

   Command (m for help): F
   Unpartitioned space /dev/sda: 20.95 GiB, 22499295232 bytes, 43943936 sectors
   Units: sectors of 1 * 512 = 512 bytes
   Sector size (logical/physical): 512 bytes / 512 bytes

       Start       End  Sectors Size
   102856704 146800639 43943936  21G
   ```

5. Now we only have `/dev/sda1`. To increase its size, we should delete the
   partition first and recreate it with 20 GB extra size.

   ```console
   Command (m for help): d
   Selected partition 1
   Partition 1 has been deleted.


   Command (m for help): n
   Partition type
      p   primary (0 primary, 0 extended, 4 free)
      e   extended (container for logical partitions)
   Select (default p): p
   Partition number (1-4, default 1): 1
   First sector (2048-146800639, default 2048):
   Last sector, +/-sectors or +/-size{K,M,G,T,P} (2048-146800639, default 146800639): 144803837

   Created a new partition 1 of type 'Linux' and of size 69 GiB.
   Partition #1 contains a ext4 signature.

   Do you want to remove the signature? [Y]es/[N]o: n
   ```

   Note that `fdisk` does not support a human-readable unit or simply specifying
   an increment in size. You have to work out the numbers in sectors yourself.

6. Then we will recrate the extended partition, swap partition, and change its
   type. 

   ```console
   Command (m for help): n
   Partition type
      p   primary (1 primary, 0 extended, 3 free)
      e   extended (container for logical partitions)
   Select (default p): e
   Partition number (2-4, default 2): 2
   First sector (144803838-146800639, default 144803840):
   Last sector, +/-sectors or +/-size{K,M,G,T,P} (144803840-146800639, default 146800639):

   Created a new partition 2 of type 'Extended' and of size 975 MiB.

   Command (m for help): n
   All space for primary partitions is in use.
   Adding logical partition 5
   First sector (144805888-146800639, default 144805888):
   Last sector, +/-sectors or +/-size{K,M,G,T,P} (144805888-146800639, default 146800639):

   Created a new partition 5 of type 'Linux' and of size 974 MiB.

   Command (m for help): t
   Partition number (1,2,5, default 5):
   Hex code or alias (type L to list all): 82

   Changed type of partition 'Linux' to 'Linux swap / Solaris'.


   Command (m for help): p
   Disk /dev/sda: 70 GiB, 75161927680 bytes, 146800640 sectors
   Disk model: QEMU HARDDISK
   Units: sectors of 1 * 512 = 512 bytes
   Sector size (logical/physical): 512 bytes / 512 bytes
   I/O size (minimum/optimal): 512 bytes / 512 bytes
   Disklabel type: dos
   Disk identifier: 0xf9687e2f

   Device     Boot     Start       End   Sectors  Size Id Type
   /dev/sda1            2048 144803837 144801790   69G 83 Linux
   /dev/sda2       144803840 146800639   1996800  975M  5 Extended
   /dev/sda5       144805888 146800639   1994752  974M 82 Linux swap / Solaris
   ```

   Take a look at the partition table to make sure everything is right. Next, we
   will save the table which will exit `fdisk`.

   ```console
   Command (m for help): w
   The partition table has been altered.
   Syncing disks.
   ```

7. The partition table is changed, but we are not done yet. As we have deleted
   and recreated the swap partition, it does not have a valid UUID yet. After a
   new one is generated, it will surely be different from the previous, so that
   the OS and kernel do not know where the new swap is.

   ```shell
   sudo partprobe /dev/sda
   sudo mkswap /dev/sda5

   Setting up swapspace version 1, size = 974 MiB (1021308928 bytes)
   no label, UUID=6e88d9a6-bcc4-423b-9d18-bd81c370ef3b
   ```

   Above comments will make the new partition as the swap partition. Next we
   need copy this new UUID to replace the existing one in
   `/etc/initramfs-tools/conf.d/resume`.

   ```shell
   sudo echo "RESUME=UUID=6e88d9a6-bcc4-423b-9d18-bd81c370ef3b" > /etc/initramfs-tools/conf.d/resume
   ```

   Then rebuild the kernel and reenable swap.

   ```shell
   sudo update-initramfs -u
   sudo swapon -a
   ```

   After this, you should be all set.

Be very careful that this may result in a data loss. Since I am doing all of
this in a VM, the whole VM has been backed up and I can easily restore
everything in seconds, so I was not afraid of a data loss. If you are doing this
on a bare-metal installation, be extremely careful.