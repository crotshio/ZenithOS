#!/usr/bin/env bash
set -e

### COLORS ###
Y="\e[33m"
G="\e[32m"
R="\e[31m"
C="\e[36m"
N="\e[0m"

echo -e "${C}==============================${N}"
echo -e "${C}   ZenithOS UEFI Installer    ${N}"
echo -e "${C}==============================${N}"
echo
echo -e "${Y}This script will install ZenithOS on /dev/sda.${N}"
echo -e "${Y}It will ERASE ALL DATA on that drive.${N}"
echo
read -p "Type YES to continue: " confirm

if [[ "$confirm" != "YES" ]]; then
    echo -e "${R}Installation cancelled.${N}"
    exit 1
fi

### CHECK UEFI ###
if [[ ! -d /sys/firmware/efi/efivars ]]; then
    echo -e "${R}ERROR: System is NOT in UEFI mode.${N}"
    echo -e "${R}Enable EFI in VirtualBox → Settings → System → Enable EFI${N}"
    exit 1
fi

### DISK SETUP ###
echo -e "${G}Partitioning /dev/sda ...${N}"

sgdisk -Z /dev/sda
sgdisk -n 1:0:+512M -t 1:ef00 /dev/sda
sgdisk -n 2:0:0   -t 2:8300 /dev/sda

mkfs.fat -F32 /dev/sda1
mkfs.ext4 -F /dev/sda2

mount /dev/sda2 /mnt
mount --mkdir /dev/sda1 /mnt/boot

### BASE SYSTEM ###
echo -e "${G}Installing base system...${N}"

pacstrap -K /mnt base linux linux-firmware base-devel networkmanager nano

genfstab -U /mnt >> /mnt/etc/fstab

### CHROOT CONFIG ###
echo -e "${G}Entering chroot...${N}"

arch-chroot /mnt /bin/bash << 'EOF'

# Timezone
ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime
hwclock --systohc

# Locale
sed -i 's/#en_GB.UTF-8/en_GB.UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_GB.UTF-8" > /etc/locale.conf

# Hostname
echo "zenithos" > /etc/hostname

# Networking
systemctl enable NetworkManager

# UEFI GRUB INSTALL
pacman -S --noconfirm grub efibootmgr

mkdir -p /boot
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=ZenithOS
grub-mkconfig -o /boot/grub/grub.cfg

# USER
useradd -m ash
echo "ash:zenith" | chpasswd
usermod -aG wheel ash

# Sudoers
sed -i 's/# %wheel/%wheel/' /etc/sudoers

# KDE Plasma + essentials
pacman -S --noconfirm plasma-desktop sddm dolphin konsole \
    kde-gtk-config plasma-nm plasma-pa powerdevil khotkeys \
    ark spectacle bluedevil gwenview

systemctl enable sddm

# Audio stack
pacman -S --noconfirm pipewire pipewire-pulse pipewire-alsa wireplumber

EOF

### FINISH ###
umount -R /mnt

echo -e "${G}Installation complete!${N}"
echo -e "${C}Reboot now and enjoy ZenithOS Plasma.${N}"
