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

open_vm_tools="{{openVmTools}}"
vmtoolsd="$open_vm_tools/bin/vmtoolsd"
vmware_rpctool="$open_vm_tools/bin/vmware-rpctool"
vmware_user_suid="$open_vm_tools/bin/vmware-user-suid-wrapper"
vmware_vmblock_fuse="$open_vm_tools/bin/vmware-vmblock-fuse"

failures=0

check_failed() {
  failures=$((failures + 1))
  echo "ERROR: $1" >&2
}

require_host_command() {
  name="$1"
  shift
  for candidate in "$@"; do
    if [ -x "$candidate" ]; then
      echo "$candidate"
      return 0
    fi
  done
  check_failed "host command $name not found"
  return 1
}

sudo_bin="$(require_host_command sudo /usr/bin/sudo /bin/sudo || true)"
systemctl_bin="$(require_host_command systemctl /usr/bin/systemctl /bin/systemctl || true)"
modprobe_bin=""
for candidate in /usr/bin/modprobe /sbin/modprobe /bin/modprobe; do
  if [ -x "$candidate" ]; then
    modprobe_bin="$candidate"
    break
  fi
done

if [ ! -x "$vmtoolsd" ]; then
  check_failed "Nix open-vm-tools does not provide vmtoolsd at $vmtoolsd"
fi

if [ ! -x "$vmware_rpctool" ]; then
  check_failed "Nix open-vm-tools does not provide vmware-rpctool at $vmware_rpctool"
fi

if [ "$failures" -gt 0 ]; then
  echo "VMware tools verification failed before system setup." >&2
  exit 1
fi

tools_dir=/etc/vmware-tools
tools_conf="$tools_dir/tools.conf"
nix_tools_conf="$open_vm_tools/etc/vmware-tools/tools.conf"
nix_tools_conf_example="$open_vm_tools/etc/vmware-tools/tools.conf.example"
tmp_tools_conf="$(/usr/bin/mktemp)"

"$sudo_bin" /usr/bin/mkdir -p "$tools_dir"
if [ ! -f "$tools_conf" ]; then
  if [ -f "$nix_tools_conf" ]; then
    "$sudo_bin" /usr/bin/cp "$nix_tools_conf" "$tools_conf"
  elif [ -f "$nix_tools_conf_example" ]; then
    "$sudo_bin" /usr/bin/cp "$nix_tools_conf_example" "$tools_conf"
  fi
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

"$sudo_bin" /usr/bin/install -m 0644 "$tmp_tools_conf" "$tools_conf"
/usr/bin/rm -f "$tmp_tools_conf"
echo "Configured $tools_conf with resolutionKMS enabled."

vmwgfx_prestart=/usr/local/libexec/ripper-vmwgfx-prestart
tmp_vmwgfx_prestart="$(/usr/bin/mktemp)"
/usr/bin/cat > "$tmp_vmwgfx_prestart" <<EOF
#!/bin/sh
if [ -d /sys/module/vmwgfx ]; then
  exit 0
fi

if [ -x "$modprobe_bin" ]; then
  "$modprobe_bin" vmwgfx && exit 0
fi

if [ -d /sys/module/vmwgfx ]; then
  exit 0
fi

echo "ripper-vmwgfx-prestart: vmwgfx kernel module is not loaded and modprobe failed" >&2
exit 1
EOF

"$sudo_bin" /usr/bin/install -Dm755 "$tmp_vmwgfx_prestart" "$vmwgfx_prestart"
/usr/bin/rm -f "$tmp_vmwgfx_prestart"

tmp_modules_load="$(/usr/bin/mktemp)"
/usr/bin/printf "vmwgfx\nfuse\n" > "$tmp_modules_load"
"$sudo_bin" /usr/bin/install -Dm644 "$tmp_modules_load" /etc/modules-load.d/ripper-vmwgfx.conf
/usr/bin/rm -f "$tmp_modules_load"

if [ -d "$open_vm_tools/lib/udev/rules.d" ]; then
  for rule in "$open_vm_tools"/lib/udev/rules.d/*.rules; do
    if [ -f "$rule" ]; then
      rule_name="${rule##*/}"
      "$sudo_bin" /usr/bin/install -Dm644 "$rule" "/etc/udev/rules.d/$rule_name"
    fi
  done
  if [ -x /usr/bin/udevadm ]; then
    "$sudo_bin" /usr/bin/udevadm control --reload-rules 2>/dev/null || true
    "$sudo_bin" /usr/bin/udevadm trigger 2>/dev/null || true
  fi
fi

setuid_wrapper=/usr/local/libexec/ripper-vmware-user-suid-wrapper
if [ -x "$vmware_user_suid" ]; then
  "$sudo_bin" /usr/bin/install -Dm4755 "$vmware_user_suid" "$setuid_wrapper"
  echo "Configured setuid VMware user wrapper: $setuid_wrapper."
else
  echo "Nix open-vm-tools does not include vmware-user-suid-wrapper; vmtoolsd -n vmusr will be used for the X session."
fi

vmtools_unit=/etc/systemd/system/vmtoolsd.service
tmp_vmtools_unit="$(/usr/bin/mktemp)"
/usr/bin/cat > "$tmp_vmtools_unit" <<EOF
[Unit]
Description=VMware Tools Daemon (Nix open-vm-tools managed by Ripper)
Documentation=https://github.com/vmware/open-vm-tools
ConditionVirtualization=vmware
Wants=systemd-modules-load.service vmware-vmblock-fuse.service
After=systemd-modules-load.service systemd-udevd.service vmware-vmblock-fuse.service

[Service]
Type=simple
ExecStartPre=$vmwgfx_prestart
ExecStart=$vmtoolsd -c $tools_conf
Restart=always
RestartSec=1

[Install]
WantedBy=multi-user.target
EOF

"$sudo_bin" /usr/bin/install -Dm644 "$tmp_vmtools_unit" "$vmtools_unit"
/usr/bin/rm -f "$tmp_vmtools_unit"
echo "Configured $vmtools_unit."

vmblock_unit=/etc/systemd/system/vmware-vmblock-fuse.service
if [ -x "$vmware_vmblock_fuse" ]; then
  tmp_vmblock_unit="$(/usr/bin/mktemp)"
  /usr/bin/cat > "$tmp_vmblock_unit" <<EOF
[Unit]
Description=Ripper VMware vmblock FUSE service
Documentation=https://github.com/vmware/open-vm-tools/blob/master/open-vm-tools/vmblock-fuse/design.txt
ConditionVirtualization=vmware
Before=vmtoolsd.service

[Service]
Type=forking
RuntimeDirectory=vmblock-fuse
RuntimeDirectoryMode=755
ExecStart=$vmware_vmblock_fuse -o subtype=vmware-vmblock,default_permissions,allow_other /run/vmblock-fuse
Restart=on-failure
RestartSec=1

[Install]
WantedBy=multi-user.target
EOF
  "$sudo_bin" /usr/bin/install -Dm644 "$tmp_vmblock_unit" "$vmblock_unit"
  /usr/bin/rm -f "$tmp_vmblock_unit"
  echo "Configured $vmblock_unit."
fi

unit_exists() {
  "$systemctl_bin" list-unit-files "$1" 2>/dev/null | {{gnuGrep}}/bin/grep -q "^$1"
}

for svc in ripper-vmtoolsd.service ripper-vmblock-fuse.service open-vm-tools.service vmware.service; do
  if unit_exists "$svc"; then
    "$sudo_bin" "$systemctl_bin" disable --now "$svc" 2>/dev/null \
      || echo "WARNING: could not disable distro VMware service $svc"
  fi
done

"$sudo_bin" /usr/bin/rm -f \
  /etc/systemd/system/ripper-vmtoolsd.service \
  /etc/systemd/system/ripper-vmblock-fuse.service \
  /etc/systemd/system/vmtoolsd.service.d/10-ripper-vmwgfx.conf \
  /etc/systemd/system/open-vm-tools.service.d/10-ripper-vmwgfx.conf
"$sudo_bin" /usr/bin/rm -rf \
  /etc/systemd/system/ripper-vmtoolsd.service.d \
  /etc/systemd/system/ripper-vmblock-fuse.service.d

"$sudo_bin" "$systemctl_bin" daemon-reload

if [ -x "$vmware_vmblock_fuse" ]; then
  "$sudo_bin" "$systemctl_bin" enable --now vmware-vmblock-fuse.service 2>/dev/null \
    || echo "WARNING: could not enable vmware-vmblock-fuse.service"
fi

"$sudo_bin" "$systemctl_bin" enable --now vmtoolsd.service
"$sudo_bin" "$systemctl_bin" restart vmtoolsd.service

if [ ! -d /sys/module/vmwgfx ]; then
  "$sudo_bin" "$vmwgfx_prestart" || true
fi

if [ ! -d /sys/module/vmwgfx ]; then
  check_failed "vmwgfx is not loaded; VMware dynamic resolution cannot work."
else
  echo "vmwgfx kernel module is loaded."
fi

if ! /usr/bin/find "$open_vm_tools" -type f -name '*resolution*.so' 2>/dev/null \
  | {{gnuGrep}}/bin/grep -qi resolution; then
  check_failed "Nix open-vm-tools resolution plugin was not found in $open_vm_tools."
else
  echo "Nix open-vm-tools resolution plugin is installed."
fi

if "$systemctl_bin" is-active --quiet vmtoolsd.service; then
  echo "vmtoolsd.service is active."
else
  check_failed "vmtoolsd.service is not active."
  "$systemctl_bin" --no-pager --full status vmtoolsd.service 2>/dev/null || true
  "$systemctl_bin" --no-pager --full status vmware-vmblock-fuse.service 2>/dev/null || true
  /usr/bin/journalctl --no-pager -u vmtoolsd.service -n 120 2>/dev/null || true
fi

if [ ! -x "$setuid_wrapper" ] && [ ! -x "$vmtoolsd" ]; then
  check_failed "no VMware X11 user agent command found."
else
  echo "VMware X11 user agent command is available."
fi

if [ ! -x "$vmware_rpctool" ]; then
  check_failed "vmware-rpctool was not found in Nix open-vm-tools."
else
  echo "vmware-rpctool is available from Nix open-vm-tools."
fi

if [ "$failures" -gt 0 ]; then
  echo "VMware tools verification failed with $failures problem(s)." >&2
  exit 1
fi

echo "VMware tools verification passed."
