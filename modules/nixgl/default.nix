{ config, pkgs, nixgl, ... }:

pkg:

let
  nixglPkgs = import nixgl { inherit pkgs; };

  nixGL = "${nixglPkgs.auto.nixGLDefault}/bin/nixGL";
in
  pkg.overrideAttrs (old: {
    name = "nixGL-${pkg.name}";
    buildCommand = ''
      set -eo pipefail

      ${pkgs.lib.concatStringsSep "\n" (map (outputName: ''
        echo "Copying output ${outputName}"
        set -x
        cp -rs --no-preserve=mode "${pkg.${outputName}}" "''$${outputName}"
        set +x
      '') (old.outputs or [ "out" ]))}

      rm -rf $out/bin/*
      shopt -s nullglob
      for file in ${pkg.out}/bin/*; do
        wrapper="$out/bin/$(basename $file)"
        echo "#!${pkgs.bash}/bin/bash" > "$wrapper"
        echo "exec -a \"\$0\" ${nixGL} \"$file\" \"\$@\"" >> "$wrapper"
        chmod +x "$wrapper"
      done
      shopt -u nullglob
    '';
  })

