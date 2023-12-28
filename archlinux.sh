#!/usr/bin/env bash
echo ""
echo "================================================================="
echo "==        Welcome To The Arch Linux Installation Script        =="
echo "================================================================="

timedatectl set-ntp true

echo ""
echo "================================================================="
echo "==                     Partition The Drive                     =="
echo "================================================================="
echo ""
# Display available disks for the user to choose
echo "Available Disks: "
lsblk -d -o NAME,SIZE
echo "="
echo "Enter The Disk To Use ( Example: /dev/sda or /dev/nvme0n1 ): "
read DISK
# Manual partitioning
echo "Manual Partitioning..."
cfdisk "$DISK"
echo "="
echo "Please Enter EFI Paritition: ( Example: /dev/sda1 or /dev/nvme0n1p1 ): "
read EFI
echo "="
echo "Please Enter Root Paritition: ( Example: /dev/sda2 or /dev/nvme0n1p2 ): "
read ROOT
echo "="
echo "Please Enter Your hostname: "
read HOSTNAME
echo "="
echo "Please Enter Your hostname password: "
read HOSTNAMEPASSWORD
echo "="
echo "Please Enter Your username: "
read USERNAME
echo "="
echo "Please Enter Your username password: "
read USERNAMEPASSWORD
echo "="
echo "Enter Your Locale ( Example: en_US.UTF-8 ): "
read LOCALE
echo "="
echo "Enter Your Keyboard Layout ( Example: us ): "
read KEYBOARD_LAYOUT
echo "="
echo "Please Chosse The Kernel: "
echo "1. for Linux"
echo "2. for Linux-lts"
read KERNEL
echo "="
echo "Please Choose Your Desktop Environment: "
echo "1. for CINNAMON"
echo "2. for GNOME"
echo "3. for KDE"
echo "4. for No Desktop"
read DESKTOP
echo "Do You Want To Install Office: "
echo "1. for WPS-Office"
echo "2. for OnlyOffice"
echo "3. for I Don't want To Install"
read OFFICE
echo "Do You Want To Install Virtualbox: "
echo "1. for Yes"
echo "2. for No"
read VIRTUALBOX
echo "="
echo "================================================================="
echo "==                      Format And Mount                       =="
echo "================================================================="

mkfs.vfat -F32 -n "EFISYSTEM" "${EFI}"
mkfs.ext4 -L "ROOT" "${ROOT}"

mount -t ext4 "${ROOT}" /mnt
mkdir /mnt/boot
mount -t vfat "${EFI}" /mnt/boot/

echo "================================================================="
echo "==                    INSTALLING Arch Linux                    =="
echo "================================================================="

if [ $KERNEL == "1" ]
then
    pacstrap -K /mnt base base-devel linux linux-firmware linux-headers
else
    pacstrap -K /mnt base base-devel linux-lts linux-firmware linux-lts-headers
fi

pacstrap -K /mnt nano amd-ucode grub efibootmgr git wget reflector rsync networkmanager wireless_tools mtools net-tools dosfstools openssh --noconfirm --needed

# fstab
genfstab -U /mnt >> /mnt/etc/fstab

# echo "=================================================="
# echo "==       Bootloader Installation  Systemd       =="
# echo "=================================================="

# bootctl install --path /mnt/boot
# echo "default arch.conf" >> /mnt/boot/loader/loader.conf
# cat <<EOF > /mnt/boot/loader/entries/arch.conf
# title Arch Linux
# linux /vmlinuz-linux-lts
# initrd /initramfs-linux-lts.img
# options root=${ROOT} rw
# EOF

cat <<REALEND > /mnt/next.sh
echo "$HOSTNAME:$HOSTNAMEPASSWORD" | chpasswd
useradd -m $USERNAME
usermod -aG wheel $USERNAME
echo "$USERNAME:$USERNAMEPASSWORD" | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

echo "================================================================="
echo "==                 Setup Language and Set Locale               =="
echo "================================================================="

sed -i "s/^#$LOCALE/$LOCALE/" /etc/locale.gen
echo "LANG=$LOCALE" >> /etc/locale.conf
echo "KEYMAP=$KEYBOARD_LAYOUT" >> /etc/vconsole.conf
locale-gen

ln -sf /usr/share/zoneinfo/$(timedatectl | awk '/Time zone/ {print $3}') /etc/localtime
hwclock --systohc

echo "$HOSTNAME" > /etc/hostname
cat <<EOF > /etc/hosts
127.0.0.1	localhost
::1			localhost
127.0.1.1	$HOSTNAME.localdomain	$HOSTNAME
EOF

echo "================================================================="
echo "==                      Installing Grub                        =="
echo "================================================================="

grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Archlinux
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet splash udev.log_priority=3"/' /etc/default/grub
sed -i 's/GRUB_TIMEOUT_STYLE=menu/GRUB_TIMEOUT_STYLE=hidden/' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

echo "================================================================="
echo "==                    Enable Multilib Repo                     =="
echo "================================================================="

pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
pacman-key --lsign-key 3056513887B78AEB
pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'

sed -i "s/^#Color/Color/" /etc/pacman.conf
sed -i "/Color/a ILoveCandy" /etc/pacman.conf
sed -i "s/^#ParallelDownloads = 5/ParallelDownloads = 4/" /etc/pacman.conf

echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf
echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist\n" >> /etc/pacman.conf

pacman -Sy pamac-aur brave-bin --noconfirm --needed
sed -i "s/^#EnableAUR/EnableAUR/" /etc/pamac.conf
pamac update all --no-confirm --needed

echo "================================================================="
echo "==    Installing Display, Audio, Printer, Bluetooth Drivers    =="
echo "================================================================="

pacman -S xorg-server xorg-xkill xf86-video-amdgpu nvidia-lts nvidia-prime nvidia-utils lib32-nvidia-utils nvidia-settings opencl-nvidia libxnvctrl libxcrypt-compat xf86-input-libinput libinput touchegg xdg-user-dirs bash-completion bluez bluez-utils cups pipewire pipewire-audio pipewire-alsa pipewire-jack pipewire-pulse libpipewire downgrade --noconfirm --needed

systemctl enable NetworkManager
systemctl enable bluetooth
systemctl enable cups
systemctl enable touchegg
systemctl enable sshd
systemctl enable fstrim.timer

#DESKTOP ENVIRONMENT
if [[ $DESKTOP == "1" ]]
then
    pacman -S cinnamon nemo nemo-fileroller xed gnome-terminal fish gnome-themes-extra gnome-keyring system-config-printer lightdm lightdm-slick-greeter blueman numlockx exfatprogs f2fs-tools traceroute cronie gufw geary gnome-online-accounts gnome-system-monitor gnome-screenshot transmission-gtk gnome-calculator gnome-calendar simple-scan kdenlive mediainfo shotwell gimp xournalpp redshift openvpn networkmanager-openvpn noto-fonts noto-fonts-emoji ibus-typing-booster audacity vlc mplayer obs-studio gparted ttf-dejavu ttf-hanazono gvfs-afc gvfs-goa gvfs-google gvfs-mtp gvfs-gphoto2 gvfs-nfs nfs-utils ntfs-3g unrar unzip lzop gdb mtpfs ffmpegthumbs ffmpeg openh264 nodejs npm python-pip pyenv postgresql mariadb android-tools vala steam --noconfirm --needed
    systemctl enable lightdm
    sed -i "s/^#greeter-session=example-gtk-gnome/greeter-session=lightdm-slick-greeter/" /etc/lightdm/lightdm.conf
elif [[ $DESKTOP == "2" ]]
then
    pacman -S gnome-shell gnome-control-center gnome-terminal fish gnome-themes-extra gnome-keyring gnome-backgrounds gnome-tweaks gnome-shell-extensions gnome-browser-connector gnome-text-editor nautilus file-roller gdm exfatprogs f2fs-tools traceroute cronie gufw geary gnome-online-accounts gnome-system-monitor gnome-screenshot transmission-gtk gnome-calculator gnome-calendar simple-scan kdenlive mediainfo shotwell gimp xournalpp openvpn networkmanager-openvpn noto-fonts noto-fonts-emoji ibus-typing-booster audacity vlc mplayer obs-studio gparted ttf-dejavu ttf-hanazono gvfs-afc gvfs-goa gvfs-google gvfs-mtp gvfs-gphoto2 gvfs-nfs nfs-utils ntfs-3g unrar unzip lzop gdb mtpfs ffmpegthumbs ffmpeg openh264 nodejs npm python-pip pyenv postgresql mariadb android-tools vala steam --noconfirm --needed
    systemctl enable gdm
elif [[ $DESKTOP == "3" ]]
then
    pacman -S plasma-desktop dolphin dolphin-plugins ark konsole fish okular gwenview plasma-nm plasma-pa kdeplasma-addons kde-gtk-config powerdevil bluedevil kscreen kinfocenter sddm sddm-kcm kalk kate ksysguard exfatprogs f2fs-tools traceroute cronie ufw spectacle ktorrent merkuro mailspring skanlite kdenlive mediainfo gimp xournalpp openvpn networkmanager-openvpn noto-fonts noto-fonts-emoji audacity vlc mplayer obs-studio partitionmanager ttf-dejavu ttf-hanazono gvfs-afc gvfs-goa gvfs-google gvfs-mtp gvfs-gphoto2 gvfs-nfs nfs-utils ntfs-3g unrar unzip lzop gdb mtpfs ffmpegthumbs ffmpeg openh264 nodejs npm python-pip pyenv postgresql mariadb android-tools vala steam --noconfirm --needed
    systemctl enable sddm
    sed -i "s/Current=/Current=breeze/" /usr/lib/sddm/sddm.conf.d/default.conf
else
    echo "Desktop Will Not Be Installed"
fi

#OFFICE INSTALLATION
if [[ $OFFICE == "1" ]]
then
    pacman -S wps-office --noconfirm --needed
elif [[ $OFFICE == "2" ]]
then
    pacman -S onlyoffice-bin --noconfirm --needed
else
    "Office Will Not Be Installed"
fi

#VIRTUALBOX INSTALLATION
if [[ $KERNEL == "1" ]] && [[ $VIRTUALBOX == "1" ]]
then
    pacman -S virtualbox virtualbox-guest-utils virtualbox-guest-iso virtualbox-host-modules-arch --noconfirm --needed
elif [[ $KERNEL == "2" ]] && [[ $VIRTUALBOX == "1" ]]
then
    pacman -S virtualbox virtualbox-guest-utils virtualbox-guest-iso virtualbox-host-dkms --noconfirm --needed
else
    "Virtualbox Will Not Be Installed"
fi

REALEND


arch-chroot /mnt sh next.sh

#Rebooting The System
echo "================================================================="
echo "==       Installation Complete. Rebooting in 10 Seconds...     =="
echo "================================================================="
sleep 10
reboot
