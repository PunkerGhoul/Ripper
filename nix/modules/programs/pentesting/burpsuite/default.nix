{ pkgs, lib, ... }:

let
  proEdition = false;
  version = "2026.1.2";
  product =
    if proEdition then
      {
        displayName = "Burp Suite Professional";
        jarHash = "sha256-KF6VOXO3IKsysA3SBJJzL+G2yQEVpCQKL6IMYQhYFMc=";
        productName = "pro";
      }
    else
      {
        displayName = "Burp Suite Community";
        jarHash = "sha256-5LNzF68VhGdWttzZCkw/Ign4x6V4EhU/EHMddeSVirk=";
        productName = "community";
      };

  burpJarSrc = pkgs.fetchurl {
    name = "burpsuite-${product.productName}-${version}.jar";
    urls = [
      "https://portswigger-cdn.net/burp/releases/download?product=${product.productName}&version=${version}&type=Jar"
      "https://portswigger.net/burp/releases/download?product=${product.productName}&version=${version}&type=Jar"
      "https://web.archive.org/web/https://portswigger.net/burp/releases/download?product=${product.productName}&version=${version}&type=Jar"
    ];
    hash = product.jarHash;
  };

  burpJar = pkgs.runCommand "burpsuite-${product.productName}-${version}-patched.jar"
    {
      nativeBuildInputs = [
        pkgs.python3
        pkgs.unzip
        pkgs.zip
      ];
    }
    ''
      workdir="$(mktemp -d)"
      trap 'rm -rf "$workdir"' EXIT

      cp ${burpJarSrc} "$workdir/burpsuite.jar"
      cd "$workdir"
      unzip -qq burpsuite.jar -d unpacked

      python3 -c '
import json
from pathlib import Path

auto_update_path = Path("unpacked/resources/Preferences/AutoUpdateDefaults.json")
data = {}
if auto_update_path.exists():
    data = json.loads(auto_update_path.read_text())
data.setdefault("auto_update", {})["enabled"] = False
auto_update_path.parent.mkdir(parents=True, exist_ok=True)
auto_update_path.write_text(json.dumps(data, separators=(",", ":")))
'

      cd unpacked
      zip -qr "$out" .
    '';

  burpIcon = pkgs.runCommand "burpsuite-${product.productName}-${version}.png"
    {
      nativeBuildInputs = [ pkgs.unzip ];
    }
    ''
      unzip -p ${lib.escapeShellArg burpJar} resources/Media/icon64${product.productName}.png > "$out"
    '';

  burpsuite = pkgs.writeShellApplication {
    name = "burpsuite";
    runtimeInputs = [ pkgs.jdk ];
    text = ''
      exec ${pkgs.jdk}/bin/java \
        -Dawt.useSystemAAFontSettings=on \
        -Dswing.aatext=true \
        -jar ${lib.escapeShellArg burpJar} "$@"
    '';
  };
in
{
  home.packages = [ burpsuite ];

  home.file.".local/share/applications/burpsuite.desktop" = {
    text = ''
      [Desktop Entry]
      Type=Application
      Version=1.5
      Name=${product.displayName}
      GenericName=Web security testing proxy
      Comment=Burp Suite Community Edition
      Exec=${burpsuite}/bin/burpsuite
      Icon=${burpIcon}
      Terminal=false
      Categories=Development;Security;WebDevelopment;
      StartupWMClass=burp-StartBurp
    '';
  };
}
