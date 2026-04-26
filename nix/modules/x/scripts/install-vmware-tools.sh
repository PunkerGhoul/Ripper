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
  if /usr/bin/apt-cache show xserver-xorg-video-vmware >/dev/null 2>&1; then
    /usr/bin/sudo /usr/bin/apt install -y xserver-xorg-video-vmware
  else
    echo "Optional package xserver-xorg-video-vmware not found; using Xorg modesetting with vmwgfx."
  fi
elif [ -x /usr/bin/pacman ]; then
  /usr/bin/sudo /usr/bin/pacman -Syu --needed --noconfirm open-vm-tools gtkmm3 libxtst fuse3
  if /usr/bin/pacman -Si xf86-video-vmware >/dev/null 2>&1; then
    /usr/bin/sudo /usr/bin/pacman -S --needed --noconfirm xf86-video-vmware
  else
    echo "Optional package xf86-video-vmware not found; using Xorg modesetting with vmwgfx."
  fi
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

vmwgfx_prestart=/usr/local/libexec/ripper-vmwgfx-prestart
tmp_vmwgfx_prestart="$(/usr/bin/mktemp)"
/usr/bin/cat > "$tmp_vmwgfx_prestart" <<'EOF'
#!/bin/sh
if [ -d /sys/module/vmwgfx ]; then
  exit 0
fi

for modprobe in /usr/bin/modprobe /sbin/modprobe /bin/modprobe; do
  if [ -x "$modprobe" ]; then
    "$modprobe" vmwgfx && exit 0
  fi
done

if [ -d /sys/module/vmwgfx ]; then
  exit 0
fi

echo "ripper-vmwgfx-prestart: vmwgfx kernel module is not loaded and modprobe failed" >&2
exit 1
EOF

/usr/bin/sudo /usr/bin/install -Dm755 "$tmp_vmwgfx_prestart" "$vmwgfx_prestart"
/usr/bin/rm -f "$tmp_vmwgfx_prestart"

tmp_modules_load="$(/usr/bin/mktemp)"
/usr/bin/printf "vmwgfx\n" > "$tmp_modules_load"
/usr/bin/sudo /usr/bin/install -Dm644 "$tmp_modules_load" /etc/modules-load.d/ripper-vmwgfx.conf
/usr/bin/rm -f "$tmp_modules_load"

write_vmtools_dropin() {
  service="$1"
  dropin_dir="/etc/systemd/system/$service.d"
  dropin_path="$dropin_dir/10-ripper-vmwgfx.conf"
  tmp_dropin="$(/usr/bin/mktemp)"
  /usr/bin/cat > "$tmp_dropin" <<EOF
[Service]
ExecStartPre=$vmwgfx_prestart
EOF
  /usr/bin/sudo /usr/bin/mkdir -p "$dropin_dir"
  /usr/bin/sudo /usr/bin/install -m 0644 "$tmp_dropin" "$dropin_path"
  /usr/bin/rm -f "$tmp_dropin"
  echo "Configured $dropin_path."
}

unit_exists() {
  /usr/bin/systemctl list-unit-files "$1" 2>/dev/null | {{gnuGrep}}/bin/grep -q "^$1"
}

for svc in open-vm-tools.service vmtoolsd.service; do
  if [ -x /usr/bin/systemctl ] && unit_exists "$svc"; then
    write_vmtools_dropin "$svc"
  fi
done

if [ -x /usr/bin/systemctl ]; then
  /usr/bin/sudo /usr/bin/systemctl daemon-reload

  for svc in vgauthd.service open-vm-tools.service vmtoolsd.service vmware-vmblock-fuse.service; do
    if unit_exists "$svc"; then
      /usr/bin/sudo /usr/bin/systemctl enable --now "$svc" 2>/dev/null \
        || echo "WARNING: could not enable $svc"
      case "$svc" in
        vgauthd.service|open-vm-tools.service|vmtoolsd.service)
          /usr/bin/sudo /usr/bin/systemctl restart "$svc" 2>/dev/null \
            || echo "WARNING: could not restart $svc"
          ;;
      esac
    fi
  done
else
  echo "WARNING: systemctl not found. Enable open-vm-tools/vmtoolsd manually."
fi

failures=0

check_failed() {
  failures=$((failures + 1))
  echo "ERROR: $1" >&2
}

if [ ! -d /sys/module/vmwgfx ]; then
  if [ -x "$vmwgfx_prestart" ]; then
    /usr/bin/sudo "$vmwgfx_prestart" || true
  fi
fi

if [ ! -d /sys/module/vmwgfx ]; then
  check_failed "vmwgfx is not loaded; VMware dynamic resolution cannot work."
else
  echo "vmwgfx kernel module is loaded."
fi

if ! /usr/bin/find /usr/lib /usr/lib64 -type f -path '*open-vm-tools*' -name '*resolution*.so' 2>/dev/null \
  | {{gnuGrep}}/bin/grep -qi resolution; then
  check_failed "open-vm-tools resolution plugin was not found under /usr/lib; install the desktop/resolution-capable open-vm-tools build."
else
  echo "open-vm-tools resolution plugin is installed."
fi

if [ -x /usr/bin/systemctl ]; then
  tools_unit_found=false
  tools_unit_active=false

  for svc in open-vm-tools.service vmtoolsd.service; do
    if unit_exists "$svc"; then
      tools_unit_found=true
      if /usr/bin/systemctl is-active --quiet "$svc"; then
        tools_unit_active=true
        echo "$svc is active."
      else
        check_failed "$svc is installed but not active."
        /usr/bin/systemctl --no-pager --full status "$svc" 2>/dev/null || true
        /usr/bin/journalctl --no-pager -u "$svc" -n 80 2>/dev/null || true
      fi
    fi
  done

  if [ "$tools_unit_found" = "false" ]; then
    check_failed "no open-vm-tools root service found; expected open-vm-tools.service or vmtoolsd.service."
  elif [ "$tools_unit_active" = "false" ]; then
    check_failed "no open-vm-tools root service is active."
  fi

  for svc in vgauthd.service vmware-vmblock-fuse.service; do
    if unit_exists "$svc"; then
      if /usr/bin/systemctl is-active --quiet "$svc"; then
        echo "$svc is active."
      else
        check_failed "$svc is installed but not active."
        /usr/bin/systemctl --no-pager --full status "$svc" 2>/dev/null || true
        /usr/bin/journalctl --no-pager -u "$svc" -n 80 2>/dev/null || true
      fi
    fi
  done
fi

if [ ! -x /usr/bin/vmware-user-suid-wrapper ] && [ ! -x /usr/bin/vmtoolsd ] && [ ! -x /usr/bin/vmware-user ]; then
  check_failed "no VMware X11 user agent command found."
else
  echo "VMware X11 user agent command is available."
fi

if [ ! -x /usr/bin/vmware-rpctool ]; then
  check_failed "vmware-rpctool was not found; open-vm-tools base install is incomplete."
else
  echo "vmware-rpctool is available."
fi

if [ "$failures" -gt 0 ]; then
  echo "VMware tools verification failed with $failures problem(s)." >&2
  exit 1
fi

echo "VMware tools verification passed."
