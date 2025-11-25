#!/usr/bin/env bash
set -euo pipefail
trap 'echo -e "\e[31m[ERROR]\e[0m Installation failed at line $LINENO"; exit 1' ERR

### COLORS ###
Y="\e[33m"
G="\e[32m"
R="\e[31m"
C="\e[36m"
N="\e[0m"

clear
echo -e "${C}############################################${N}"
echo -e "${C}       Z  E  N  I  T  H  O  S   Installer   ${N}"
echo -e "${C}############################################${N}"
echo
echo -e "${Y}Detected SSH-friendly mode.${N}"
echo -e "${Y}Logs and progress will be printed clearly for remote install.${N}"
echo
echo -e "${R}WARNING:${N} This will ERASE the entire disk: ${Y}/dev/sda${N}"
echo

read -rp "Type YES to confirm disk wipe: " confirm
if [[ "$confirm" != "YES" ]]; then
    echo -e "${R}Installation cancelled.${N}"
    exit 1
fi

echo
echo -e "${G}[OK] Confirmation accepted.${N}"
sleep 1

### UEFI check ###
if [[ ! -d /sys/firmware/efi/efivars ]]; then
    echo -e "${R}[ERROR] System is not in UEFI mode.${N}"
    echo -e "${R}Enable EFI in VirtualBox → Settings → System → Enable EFI${N}"
    exit 1
fi

echo -e "${G}[OK] UEFI environment detected.${N}"

### DISK PARTITIONING ###
echo -e "${C}### Partitioning /dev/sda (GPT + EFI) ###${N}"

sgdisk -Z /dev/sda
sgdisk -n 1:0:+512M -t 1:ef00 /dev/sda
sgdisk -n 2:0:0      -t 2:8300 /dev/sda

echo -e "${G}[OK] Partitions created.${N}"

### FORMATTING ###
echo -e "${C}### Formatting ###${N}"

mkfs.fat -F32 /dev/sda1
mkfs.ext4 -F /dev/sda2

echo -e "${G}[OK] Filesystems formatted.${N}"

### MOUNT ###
echo -e "${C}### Mounting ###${N}"

mount /dev/sda2 /mnt
mount --mkdir /dev/sda1 /mnt/boot

echo -e "${G}[OK] Partitions mounted.${N}"

### BASE INSTALL ###
echo -e "${C}### Installing base system ###${N}"

pacstrap -K /mnt base linux linux-firmware base-devel networkmanager nano

genfstab -U /mnt >> /mnt/etc/fstab

echo -e "${G}[OK] Base system installed.${N}"

### CHROOT ###
echo -e "${C}### Entering chroot ###${N}"

arch-chroot /mnt /bin/bash << 'EOF'

set -e

echo "[CHROOT] Configuring system..."

# Time
ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime
timedatectl set-ntp true
hwclock --systohc

# Locale
sed -i 's/#en_GB.UTF-8/en_GB.UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_GB.UTF-8" > /etc/locale.conf

# Hostname
echo "zenithos" > /etc/hostname

# Network
systemctl enable NetworkManager

# Bootloader
pacman -S --noconfirm grub efibootmgr

grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=ZenithOS
grub-mkconfig -o /boot/grub/grub.cfg

# User
useradd -m ash
echo "ash:zenith" | chpasswd
usermod -aG wheel ash

# Sudo
sed -i 's/# %wheel/%wheel/' /etc/sudoers

# Desktop: KDE Plasma
pacman -S --noconfirm plasma-desktop sddm dolphin konsole \
    kde-gtk-config plasma-nm plasma-pa powerdevil khotkeys \
    ark spectacle bluedevil gwenview

systemctl enable sddm

# Audio stack
pacman -S --noconfirm pipewire pipewire-pulse pipewire-alsa wireplumber

EOF

### UNMOUNT ###
echo -e "${C}### Unmounting ###${N}"
umount -R /mnt

echo -e "${G}ZenithOS installation complete!${N}"
echo -e "${C}Reboot now to enter your new system.${N}"
