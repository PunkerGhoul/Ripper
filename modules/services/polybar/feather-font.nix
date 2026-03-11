{ pkgs }:

pkgs.stdenvNoCC.mkDerivation {
  pname = "feather-font";
  version = "unstable";
  src = pkgs.fetchurl {
    url = "https://github.com/adi1090x/polybar-themes/raw/master/fonts/feather.ttf";
    sha256 = "0n01h49l49n8n1m8g1f6dhyn6cc1d82jxmpjzs5ydsrbmxi83b4h";
  };
  dontUnpack = true;
  installPhase = ''
    mkdir -p $out/share/fonts/truetype
    cp $src $out/share/fonts/truetype/feather.ttf
  '';
}
