{ pkgs, ... }:

let
  background = "#18131f";
  surface = "#1b1326";
  surfaceAlt = "#2b2038";
  foreground = "#f7f0ff";
  muted = "#d9c7ff";
  accent = "#7b4dff";
  urgent = "#d75f8f";

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
in
{
  home.packages = [
    pkgs.thunar
    pkgs.thunar-archive-plugin
    pkgs.thunar-volman
    pkgs.tumbler
    pkgs.gvfs
    pkgs.file-roller
    pkgs.dracula-icon-theme
  ];

  gtk = {
    enable = true;
    iconTheme = {
      package = pkgs.dracula-icon-theme;
      name = "Dracula";
    };
    font = {
      package = pkgs.nerd-fonts.hack;
      name = "Hack Nerd Font";
      size = 10;
    };
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = true;
      gtk-decoration-layout = "";
      gtk-enable-animations = false;
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = true;
      gtk-decoration-layout = "";
      gtk-enable-animations = false;
    };
  };

  xdg.mimeApps.defaultApplications = {
    "inode/directory" = "thunar.desktop";
    "application/x-gnome-saved-search" = "thunar.desktop";
  };

  home.file = {
    ".config/gtk-3.0/gtk.css".text = gtkCss;
    ".config/gtk-4.0/gtk.css".text = gtkCss;
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
