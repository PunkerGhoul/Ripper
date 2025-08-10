{ pkgs, ... }:

let
  # Import bookmarks from JSON file
  bookmarksJson = builtins.fromJSON (builtins.readFile ./bookmarks.json);

  # Function to convert JSON bookmarks to Nix format
  convertBookmarks = items:
    builtins.filter (item: item != null) (builtins.map (item:
      if (item.type or "") == "text/x-moz-place-separator" then
        null  # Skip separators in nested structures - they're not supported
      else if builtins.hasAttr "children" item && item.children != [] then {
        name = item.title;
        bookmarks = convertBookmarks item.children;
      } else if builtins.hasAttr "uri" item then {
        name = item.title;
        url = item.uri;
      } else null
    ) items);

  # Convert the imported bookmarks - get the toolbar folder specifically
  toolbarFolder = builtins.head (builtins.filter
    (child: (child.root or "") == "toolbarFolder")
    bookmarksJson.children);

  # Convert toolbar bookmarks to Nix format with proper structure
  personalBookmarks = if builtins.hasAttr "children" toolbarFolder then
    let
      # Process toolbar items, handling separators only at the top level
      processToolbarItems = items:
        builtins.filter (item: item != null) (builtins.map (item:
          if (item.type or "") == "text/x-moz-place-separator" then
            "separator"  # Only at toolbar level
          else if builtins.hasAttr "children" item && item.children != [] then {
            name = item.title;
            bookmarks = convertBookmarks item.children;  # No separators in nested levels
          } else if builtins.hasAttr "uri" item then {
            name = item.title;
            url = item.uri;
          } else null
        ) items);

      toolbarBookmarks = processToolbarItems toolbarFolder.children;
    in
      # Create a single toolbar folder containing all bookmarks
      [
        {
          name = "Bookmarks Toolbar";
          toolbar = true;
          bookmarks = toolbarBookmarks;
        }
      ]
  else [];
in
  {
  programs.librewolf = {
    enable = true;

    package = pkgs.librewolf;

    profiles = {
      # Personal profile - default for daily use
      personal = {
        id = 0;
        isDefault = true;
        name = "Personal";

        # Personal use extensions
        extensions.force = true; # Required if using settings

        extensions.packages = with pkgs.nur.repos.rycee.firefox-addons; [
          ublock-origin          # uBlock0@raymondhill.net
          bitwarden             # Password manager
        ];

        extensions.settings = {
          "uBlock0@raymondhill.net".settings = {
            userSettings = {
              advancedUserEnabled = true;
            };
            whitelist = [
              "portswigger.net"
            ];
          };
        };

        # Bookmarks configuration - imported from JSON
        bookmarks = {
          force = true;  # Force apply bookmarks
          settings = personalBookmarks;  # Use the converted bookmarks
        };

        # Personal settings migrated from your LibreWolf configuration
        settings = {
          # Browser and UI
          "browser.shell.checkDefaultBrowser" = false;
          "browser.contentblocking.category" = "strict";
          "browser.download.always_ask_before_handling_new_types" = true;
          "browser.bookmarks.defaultLocation" = "toolbar";
          "browser.theme.content-theme" = 0;
          "browser.theme.toolbar-theme" = 0;
          # Note: You have "firefox-compact-dark" theme active
          # To configure it in Nix, you can use:
          # "extensions.activeThemeID" = "firefox-compact-dark@mozilla.org";

          # Extensions
          "extensions.autoDisableScopes" = 0;
          "extensions.ui.extension.hidden" = false;

          "browser.uiCustomization.state" = "{\"placements\":{\"widget-overflow-fixed-list\":[],\"unified-extensions-area\":[],\"nav-bar\":[\"sidebar-button\",\"back-button\",\"forward-button\",\"stop-reload-button\",\"customizableui-special-spring1\",\"vertical-spacer\",\"urlbar-container\",\"customizableui-special-spring2\",\"save-to-pocket-button\",\"downloads-button\",\"fxa-toolbar-menu-button\",\"ublock0_raymondhill_net-browser-action\",\"_446900e4-71c2-419f-a6a7-df9c091e268b_-browser-action\",\"unified-extensions-button\"],\"toolbar-menubar\":[\"menubar-items\"],\"TabsToolbar\":[\"tabbrowser-tabs\",\"new-tab-button\",\"alltabs-button\"],\"vertical-tabs\":[],\"PersonalToolbar\":[\"import-button\",\"personal-bookmarks\"]},\"seen\":[\"_446900e4-71c2-419f-a6a7-df9c091e268b_-browser-action\",\"ublock0_raymondhill_net-browser-action\",\"developer-button\"],\"dirtyAreaCache\":[\"unified-extensions-area\",\"nav-bar\",\"vertical-tabs\",\"PersonalToolbar\",\"toolbar-menubar\",\"TabsToolbar\"],\"currentVersion\":21,\"newElementCount\":3}";

          # Privacy and security
          "privacy.donottrackheader.enabled" = true;
          "privacy.fingerprintingProtection" = true;
          "privacy.globalprivacycontrol.was_ever_enabled" = true;
          "privacy.history.custom" = true;
          "privacy.query_stripping.enabled" = true;
          "privacy.query_stripping.enabled.pbmode" = true;
          "privacy.trackingprotection.enabled" = true;
          "privacy.trackingprotection.emailtracking.enabled" = true;
          "privacy.trackingprotection.socialtracking.enabled" = true;
          "privacy.annotate_channels.strict_list.enabled" = true;
          "privacy.bounceTrackingProtection.mode" = 1;

          # Network and connectivity
          "network.captive-portal-service.enabled" = false;
          "network.connectivity-service.enabled" = false;
          "network.dns.disableIPv6" = true;
          "network.http.speculative-parallel-limit" = 0;
          "network.predictor.enabled" = false;
          "network.prefetch-next" = false;
          ## DNS over HTTPS (DoH) settings
          "network.trr.mode" = 3; # Max Protection; 2 = Increased Protection & 1 = Default
          "network.trr.uri" = "https://dns10.quad9.net/dns-query";
          "network.trr.custom_uri" = "https://dns10.quad9.net/dns-query";
          "network.http.referer.disallowCrossSiteRelaxingDefault.top_navigation" = true;

          # Additional security
          "security.tls.enable_0rtt_data" = false;
          "dom.security.https_only_mode" = true;
          "dom.security.https_only_mode_ever_enabled" = true;
          "dom.private-attribution.submission.enabled" = false;

          # SafeBrowsing disabled (LibreWolf default)
          "browser.safebrowsing.downloads.remote.enabled" = false;
          "browser.safebrowsing.downloads.remote.block_potentially_unwanted" = false;
          "browser.safebrowsing.downloads.remote.block_uncommon" = false;

          # Forms and passwords
          "dom.forms.autocomplete.formautofill" = false;
          "signon.rememberSignons" = false; # Use Bitwarden instead
          "signon.generation.enabled" = false;
          "signon.management.page.breach-alerts.enabled" = false;

          # Developer tools
          "devtools.cache.disabled" = true;
          "devtools.debugger.remote-enabled" = false;
          "devtools.console.stdout.chrome" = false;
          "devtools.netmonitor.persistlog" = true;

          # Miscellaneous
          "findbar.highlightAll" = true;
          "intl.accept_languages" = "en-US, en";
          "javascript.use_us_english_locale" = true;
          "permissions.delegation.enabled" = false;
          "toolkit.winRegisterApplicationRestart" = false;
          "sidebar.visibility" = "hide-sidebar";
        };
      };

      # Pentesting profile - for security testing
      pentesting = {
        id = 1;
        isDefault = false;
        name = "Pentesting";

        # Pentesting extensions
        extensions.force = true; # Required if using settings

        extensions.packages = with pkgs.nur.repos.rycee.firefox-addons; [
          foxyproxy-standard     # foxyproxy@eric.h.jung - proxy management
          # Wappalyzer has a problem at build
          #wappalyzer            # wappalyzer@crunchlabz.com - technology detection
          hacktools
        ];

        containers = {
          "Zap" = {
            id = 1;
            icon = "fingerprint";
            color = "blue";
          };
          "BurpSuite" = {
            id = 2;
            icon = "dollar";
            color = "red";
          };
        };

        extensions.settings = {
          "foxyproxy@eric.h.jung".settings = {
            mode = "disable";
            sync = false;
            autoBackup = false;
            passthrough = "";
            theme = "moonlight alt";
            container = {
              incognito = "";
              "container-1" = "127.0.0.1:8081";
              "container-2" = "127.0.0.1:8080";
              "container-3" = "";
              "container-4" = "";
            };
            commands = {
              setProxy = "";
              setTabProxy = "";
              quickAdd = "";
            };
            data = [
              {
                active = true;
                title = "BurpSuite";
                type = "http";
                hostname = "127.0.0.1";
                port = "8080";
                username = "";
                password = "";
                cc = "";
                city = "";
                color = "#ff7800";
                pac = "";
                pacString = "";
                proxyDNS = true;
                include = [];
                exclude = [];
                tabProxy = [];
              }
              {
                active = true;
                title = "Zap";
                type = "http";
                hostname = "127.0.0.1";
                port = "8081";
                username = "";
                password = "";
                cc = "";
                city = "";
                color = "#3584e4";
                pac = "";
                pacString = "";
                proxyDNS = true;
                include = [];
                exclude = [];
                tabProxy = [];
              }
            ];
          };
        };

        # Pentesting-specific settings - secure but flexible for testing
        settings = {
          # Browser and UI
          "browser.shell.checkDefaultBrowser" = false;
          "browser.contentblocking.category" = "standard"; # Less strict for testing but still protected
          "browser.download.always_ask_before_handling_new_types" = true; # Keep security
          "browser.theme.content-theme" = 0;
          "browser.theme.toolbar-theme" = 0;

          # Extensions
          "extensions.autoDisableScopes" = 0;
          "extensions.ui.extension.hidden" = false;

          "browser.uiCustomization.state" = "{\"placements\":{\"widget-overflow-fixed-list\":[],\"unified-extensions-area\":[],\"nav-bar\":[\"back-button\",\"forward-button\",\"stop-reload-button\",\"customizableui-special-spring1\",\"vertical-spacer\",\"urlbar-container\",\"customizableui-special-spring2\",\"save-to-pocket-button\",\"downloads-button\",\"fxa-toolbar-menu-button\",\"unified-extensions-button\",\"foxyproxy_eric_h_jung-browser-action\",\"_f1423c11-a4e2-4709-a0f8-6d6a68c83d08_-browser-action\"],\"toolbar-menubar\":[\"menubar-items\"],\"TabsToolbar\":[\"tabbrowser-tabs\",\"new-tab-button\",\"alltabs-button\"],\"vertical-tabs\":[],\"PersonalToolbar\":[\"personal-bookmarks\"]},\"seen\":[\"foxyproxy_eric_h_jung-browser-action\",\"developer-button\",\"_f1423c11-a4e2-4709-a0f8-6d6a68c83d08_-browser-action\"],\"dirtyAreaCache\":[\"unified-extensions-area\",\"nav-bar\",\"vertical-tabs\"],\"currentVersion\":21,\"newElementCount\":2}";

          # Privacy - keep essential protections
          "privacy.donottrackheader.enabled" = false; # Don't send DNT header when testing targets
          "privacy.fingerprintingProtection" = true; # Keep for your own protection
          "privacy.globalprivacycontrol.was_ever_enabled" = true;
          "privacy.history.custom" = true;
          "privacy.query_stripping.enabled" = true; # Keep for your protection
          "privacy.query_stripping.enabled.pbmode" = true;
          "privacy.trackingprotection.enabled" = false; # Disable only for target testing
          "privacy.trackingprotection.emailtracking.enabled" = true; # Keep for your protection
          "privacy.trackingprotection.socialtracking.enabled" = true; # Keep for your protection
          "privacy.annotate_channels.strict_list.enabled" = true;
          "privacy.bounceTrackingProtection.mode" = 1;

          # Network - secure but flexible
          "network.captive-portal-service.enabled" = false; # Keep disabled for security
          "network.connectivity-service.enabled" = false; # Keep disabled for security
          "network.dns.disableIPv6" = false; # Allow IPv6 for testing
          "network.http.speculative-parallel-limit" = 0; # Keep conservative
          "network.predictor.enabled" = false; # Keep disabled for security
          "network.prefetch-next" = false; # Keep disabled for security
          "network.trr.custom_uri" = "https://dns10.quad9.net/dns-query"; # Keep secure DNS
          "network.http.referer.disallowCrossSiteRelaxingDefault.top_navigation" = true;

          # Security - maintain core protections
          "security.tls.enable_0rtt_data" = false; # Keep secure
          "dom.security.https_only_mode" = false; # Allow HTTP for testing targets
          "dom.security.https_only_mode_ever_enabled" = true;
          "dom.private-attribution.submission.enabled" = false;

          # SafeBrowsing disabled (LibreWolf default)
          "browser.safebrowsing.downloads.remote.enabled" = false;
          "browser.safebrowsing.downloads.remote.block_potentially_unwanted" = false;
          "browser.safebrowsing.downloads.remote.block_uncommon" = false;

          # Forms and passwords - enable for pentesting credentials
          "dom.forms.autocomplete.formautofill" = false;
          "signon.rememberSignons" = true; # Save test credentials in pentesting profile
          "signon.generation.enabled" = true; # Enable password generation for testing
          "signon.management.page.breach-alerts.enabled" = false;

          # Developer tools - enhanced for pentesting but secure
          "devtools.cache.disabled" = true;
          "devtools.debugger.remote-enabled" = false; # Keep disabled for security
          "devtools.console.stdout.chrome" = false; # Keep secure
          "devtools.netmonitor.persistlog" = true;
          "devtools.chrome.enabled" = true; # Enable chrome debugging for analysis

          # Miscellaneous
          "findbar.highlightAll" = true;
          "intl.accept_languages" = "en-US, en";
          "javascript.use_us_english_locale" = true;
          "permissions.delegation.enabled" = false; # Keep disabled for security
          "toolkit.winRegisterApplicationRestart" = false;
          "sidebar.visibility" = "hide-sidebar";
        };
      };
    };
  };
}
