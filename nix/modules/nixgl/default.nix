{ pkgs, nixGLCommand }:

pkg:

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
        echo "exec -a \"\$0\" ${nixGLCommand} \"$file\" \"\$@\"" >> "$wrapper"
        chmod +x "$wrapper"
      done
      shopt -u nullglob
    '';
  })
