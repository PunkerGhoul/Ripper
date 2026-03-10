echo "Checking VMware environment..."

is_vmware=false
if {{gnuGrep}}/bin/grep -qi vmware /sys/class/dmi/id/sys_vendor 2>/dev/null \
   || {{gnuGrep}}/bin/grep -qi vmware /sys/class/dmi/id/product_name 2>/dev/null; then
  is_vmware=true
fi

if [ "$is_vmware" = "false" ]; then
  if {{systemd}}/bin/systemd-detect-virt 2>/dev/null | {{gnuGrep}}/bin/grep -qi vmware; then
    is_vmware=true
  fi
fi

if [ "$is_vmware" = "false" ]; then
  if {{pciUtils}}/bin/lspci 2>/dev/null | {{gnuGrep}}/bin/grep -qi vmware; then
    is_vmware=true
  fi
fi

if [ "$is_vmware" = "false" ]; then
  echo "Not running in VMware."
  exit 0
fi

echo "VMware environment detected."

if [ -x /usr/bin/apt ]; then
  /usr/bin/sudo /usr/bin/apt update -y
  /usr/bin/sudo /usr/bin/apt install -y open-vm-tools open-vm-tools-desktop fuse3
elif [ -x /usr/bin/pacman ]; then
  /usr/bin/sudo /usr/bin/pacman -Syu --needed --noconfirm open-vm-tools gtkmm3 fuse3
else
  echo "WARNING: No supported package manager found. Install open-vm-tools, open-vm-tools-desktop and fuse3 manually."
  exit 0
fi

for svc in vmtoolsd vmware-vmblock-fuse.service; do
  /usr/bin/sudo {{systemd}}/bin/systemctl enable --now "$svc" 2>/dev/null \
    || echo "WARNING: could not enable $svc"
done
