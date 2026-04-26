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
  /usr/bin/sudo /usr/bin/apt install -y open-vm-tools open-vm-tools-desktop xserver-xorg-video-vmware fuse3
elif [ -x /usr/bin/pacman ]; then
  /usr/bin/sudo /usr/bin/pacman -Syu --needed --noconfirm open-vm-tools xf86-video-vmware gtkmm3 fuse3
else
  echo "WARNING: No supported package manager found. Install open-vm-tools, open-vm-tools-desktop and fuse3 manually."
  exit 0
fi

tools_dir=/etc/vmware-tools
tools_conf="$tools_dir/tools.conf"
tools_conf_example="$tools_dir/tools.conf.example"
tmp_tools_conf="$(/usr/bin/mktemp)"

/usr/bin/sudo /usr/bin/mkdir -p "$tools_dir"
if [ ! -f "$tools_conf" ] && [ -f "$tools_conf_example" ]; then
  /usr/bin/sudo /usr/bin/cp "$tools_conf_example" "$tools_conf"
fi

if [ -f "$tools_conf" ]; then
  /usr/bin/awk '
    BEGIN {
      in_section = 0
      seen_section = 0
    }
    /^\[resolutionKMS\]$/ {
      print
      print "enable=true"
      in_section = 1
      seen_section = 1
      next
    }
    /^\[/ {
      in_section = 0
    }
    in_section && /^[[:space:]]*#?[[:space:]]*enable[[:space:]]*=/ {
      next
    }
    {
      print
    }
    END {
      if (!seen_section) {
        print ""
        print "[resolutionKMS]"
        print "enable=true"
      }
    }
  ' "$tools_conf" > "$tmp_tools_conf"
else
  /usr/bin/printf "[resolutionKMS]\nenable=true\n" > "$tmp_tools_conf"
fi

/usr/bin/sudo /usr/bin/install -m 0644 "$tmp_tools_conf" "$tools_conf"
/usr/bin/rm -f "$tmp_tools_conf"
echo "Configured $tools_conf with resolutionKMS enabled."

if [ -x /usr/bin/systemctl ]; then
  for svc in open-vm-tools.service vmtoolsd.service vmware-vmblock-fuse.service; do
    if /usr/bin/systemctl list-unit-files "$svc" 2>/dev/null | {{gnuGrep}}/bin/grep -q "$svc"; then
      /usr/bin/sudo /usr/bin/systemctl enable --now "$svc" 2>/dev/null \
        || echo "WARNING: could not enable $svc"
      case "$svc" in
        open-vm-tools.service|vmtoolsd.service)
          /usr/bin/sudo /usr/bin/systemctl restart "$svc" 2>/dev/null \
            || echo "WARNING: could not restart $svc"
          ;;
      esac
    fi
  done
else
  echo "WARNING: systemctl not found. Enable open-vm-tools/vmtoolsd manually."
fi
