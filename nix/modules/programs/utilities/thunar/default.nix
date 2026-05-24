{ config, pkgs, ... }:

let
  background = "#18131f";
  surface = "#1b1326";
  surfaceAlt = "#2b2038";
  foreground = "#f7f0ff";
  muted = "#d9c7ff";
  accent = "#7b4dff";
  urgent = "#d75f8f";
  gvfsPackage = pkgs.gnome.gvfs;

  laCapitaineDark = pkgs.runCommand "la-capitaine-icon-theme-dark" { } ''
    mkdir -p "$out/share/icons"
    source_dir="$(find "${pkgs.la-capitaine-icon-theme}/share/icons" -mindepth 1 -maxdepth 1 -type d | sort | head -n 1)"
    if [ -z "$source_dir" ]; then
      echo "No icon theme directory found in ${pkgs.la-capitaine-icon-theme}/share/icons" >&2
      exit 1
    fi

    cp -R --no-preserve=mode,ownership "$source_dir" "$out/share/icons/La-Capitaine"

    cd "$out/share/icons/La-Capitaine"
    replace_link() {
      link="$1"
      target="$2"
      dir="$(dirname "$link")"
      if [ -e "$dir/$target" ]; then
        rm -rf "$link"
        ln -s "$target" "$link"
      fi
    }

    replace_link actions/22x22 22x22-dark
    replace_link devices/scalable scalable-dark
    replace_link emblems/scalable/avatar-default.svg avatar-default-dark.svg
    replace_link panel/16 16-dark
    replace_link panel/24 24-dark
    replace_link places/16x16 16x16-dark
    replace_link status/scalable scalable-dark
  '';

  gtkCss = ''
    @define-color ripper_bg ${background};
    @define-color ripper_surface ${surface};
    @define-color ripper_surface_alt ${surfaceAlt};
    @define-color ripper_fg ${foreground};
    @define-color ripper_muted ${muted};
    @define-color ripper_accent ${accent};
    @define-color ripper_urgent ${urgent};

    * {
      border-radius: 0;
      outline-color: @ripper_accent;
      caret-color: @ripper_fg;
    }

    window,
    dialog,
    .background,
    viewport,
    scrolledwindow,
    treeview,
    treeview.view,
    iconview,
    ThunarWindow,
    ThunarWindow .view,
    .standard-view,
    .standard-view .view,
    notebook,
    paned,
    iconview.view {
      background-color: @ripper_bg;
      color: @ripper_fg;
    }

    headerbar,
    toolbar,
    menubar,
    menu,
    popover,
    placessidebar,
    .sidebar,
    .thunar .sidebar {
      background-color: @ripper_surface;
      color: @ripper_fg;
      border-color: @ripper_surface_alt;
    }

    button,
    entry,
    combobox,
    spinbutton,
    scrollbar slider {
      background-color: @ripper_surface_alt;
      color: @ripper_fg;
      border-color: @ripper_accent;
    }

    button:hover,
    row:hover,
    treeview.view:hover,
    iconview.view:hover {
      background-color: alpha(@ripper_accent, 0.22);
      color: @ripper_fg;
    }

    button:checked,
    row:selected,
    row:selected:hover,
    treeview.view:selected,
    treeview.view:selected:focus,
    iconview.view:selected,
    iconview.view:selected:focus {
      background-color: @ripper_accent;
      color: @ripper_fg;
    }

    entry:focus,
    button:focus,
    treeview.view:focus,
    iconview.view:focus {
      border-color: @ripper_accent;
      box-shadow: inset 0 0 0 1px @ripper_accent;
    }

    label:disabled,
    button:disabled,
    image:disabled {
      color: alpha(@ripper_muted, 0.45);
    }

    progressbar progress,
    scale highlight {
      background-color: @ripper_accent;
    }

    scrollbar slider:hover {
      background-color: @ripper_accent;
    }

    tooltip {
      background-color: @ripper_surface_alt;
      color: @ripper_fg;
      border: 1px solid @ripper_accent;
    }
  '';

  thunarWrapper = ''
    #!${pkgs.runtimeShell}

    for profile in \
      "$HOME/.nix-profile" \
      "$HOME/.local/state/nix/profiles/profile" \
      "/etc/profiles/per-user/''${USER:-}"; do
      if [ -r "$profile/etc/profile.d/hm-session-vars.sh" ]; then
        . "$profile/etc/profile.d/hm-session-vars.sh"
      fi
      if [ -d "$profile/share" ]; then
        XDG_DATA_DIRS="$profile/share''${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"
      fi
    done

    export XDG_CURRENT_DESKTOP=i3
    export GTK_THEME=Adwaita:dark
    export GIO_USE_VFS=gvfs
    export GIO_EXTRA_MODULES="${gvfsPackage}/lib/gio/modules:${pkgs.glib-networking}/lib/gio/modules"
    export XDG_DATA_DIRS="${laCapitaineDark}/share:${pkgs.hicolor-icon-theme}/share:${pkgs.adwaita-icon-theme}/share:${pkgs.gnome-themes-extra}/share:${gvfsPackage}/share:${pkgs.samba}/share:$HOME/.local/share:$HOME/.nix-profile/share:$HOME/.local/state/nix/profiles/profile/share:/var/lib/flatpak/exports/share:''${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"

    if [ -z "''${DBUS_SESSION_BUS_ADDRESS:-}" ] && command -v dbus-launch >/dev/null 2>&1; then
      exec dbus-launch --exit-with-session "$0" "$@"
    fi

    user_name="''${USER:-$(${pkgs.coreutils}/bin/id -un 2>/dev/null || true)}"
    start_gvfs_daemon() {
      process_name="$1"
      daemon_path="$2"
      [ -n "$user_name" ] || return 0
      [ -x "$daemon_path" ] || return 0
      ${pkgs.procps}/bin/pgrep -u "$user_name" -x "$process_name" >/dev/null 2>&1 && return 0
      "$daemon_path" >/dev/null 2>&1 &
    }

    start_gvfs_daemon gvfsd "${gvfsPackage}/libexec/gvfsd"
    start_gvfs_daemon gvfsd-network "${gvfsPackage}/libexec/gvfsd-network"
    start_gvfs_daemon gvfsd-smb-browse "${gvfsPackage}/libexec/gvfsd-smb-browse"
    start_gvfs_daemon gvfsd-smb "${gvfsPackage}/libexec/gvfsd-smb"

    exec ${pkgs.thunar}/bin/thunar "$@"
  '';
in
{
  home.packages = [
    pkgs.thunar
    pkgs.thunar-archive-plugin
    pkgs.thunar-volman
    pkgs.tumbler
    gvfsPackage
    pkgs.samba
    pkgs.file-roller
    laCapitaineDark
    pkgs.hicolor-icon-theme
    pkgs.adwaita-icon-theme
    pkgs.gnome-themes-extra
  ];

  gtk = {
    enable = true;
    theme = {
      package = pkgs.gnome-themes-extra;
      name = "Adwaita-dark";
    };
    iconTheme = {
      package = laCapitaineDark;
      name = "La-Capitaine";
    };
    font = {
      package = pkgs.nerd-fonts.hack;
      name = "Hack Nerd Font";
      size = 10;
    };
    gtk2.extraConfig = ''
      gtk-theme-name="Adwaita-dark"
      gtk-icon-theme-name="La-Capitaine"
      gtk-font-name="Hack Nerd Font 10"
    '';
    gtk3.extraConfig = {
      gtk-theme-name = "Adwaita-dark";
      gtk-icon-theme-name = "La-Capitaine";
      gtk-application-prefer-dark-theme = true;
      gtk-decoration-layout = "";
      gtk-enable-animations = false;
    };
    gtk3.extraCss = gtkCss;
    gtk4.theme = {
      package = pkgs.gnome-themes-extra;
      name = "Adwaita-dark";
    };
    gtk4.extraConfig = {
      gtk-theme-name = "Adwaita-dark";
      gtk-icon-theme-name = "La-Capitaine";
      gtk-application-prefer-dark-theme = true;
      gtk-decoration-layout = "";
      gtk-enable-animations = false;
    };
    gtk4.extraCss = gtkCss;
  };

  xdg.mimeApps.defaultApplications = {
    "inode/directory" = "ripper-thunar.desktop";
    "application/x-gnome-saved-search" = "ripper-thunar.desktop";
  };

  home.file = {
    ".local/bin/ripper-thunar" = {
      text = thunarWrapper;
      executable = true;
    };
    ".local/share/applications/ripper-thunar.desktop".text = ''
      [Desktop Entry]
      Name=Thunar File Manager
      Comment=Browse the filesystem with Thunar
      Exec=${config.home.homeDirectory}/.local/bin/ripper-thunar %F
      Icon=system-file-manager
      Terminal=false
      Type=Application
      Categories=System;FileTools;FileManager;
      MimeType=inode/directory;application/x-gnome-saved-search;
      StartupNotify=true
    '';
    ".config/xfce4/xfconf/xfce-perchannel-xml/thunar.xml".text = ''
      <?xml version="1.0" encoding="UTF-8"?>

      <channel name="thunar" version="1.0">
        <property name="last-view" type="string" value="ThunarIconView"/>
        <property name="misc-single-click" type="bool" value="false"/>
        <property name="misc-thumbnail-mode" type="string" value="THUNAR_THUMBNAIL_MODE_ALWAYS"/>
        <property name="misc-date-style" type="string" value="THUNAR_DATE_STYLE_SIMPLE"/>
        <property name="misc-recursive-permissions" type="string" value="THUNAR_RECURSIVE_PERMISSIONS_ASK"/>
        <property name="misc-show-delete-action" type="bool" value="true"/>
        <property name="misc-middle-click-in-tab" type="bool" value="true"/>
      </channel>
    '';
  };
}
