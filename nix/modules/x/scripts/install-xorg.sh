if ! [ -x /usr/bin/X ] || ! [ -x /usr/bin/xinit ]; then
  if [ -x /usr/bin/apt ]; then
    /usr/bin/sudo /usr/bin/apt update -y
    /usr/bin/sudo /usr/bin/apt install -y xorg xorg-dev x11-apps xinit
  elif [ -x /usr/bin/pacman ]; then
    /usr/bin/sudo /usr/bin/pacman -Syu --needed --noconfirm xorg-server xorg-xinit xorg-xauth xorg-apps
  else
    echo "Warning: no supported package manager found. Install xorg-server, xorg-xinit, xorg-xauth, xorg-apps manually."
  fi
fi
