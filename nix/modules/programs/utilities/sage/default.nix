{ lib, nixosPkgs, ... }:

let
  disablePythonChecks = old: old.overridePythonAttrs (_: {
    doCheck = false;
    doInstallCheck = false;
    pythonImportsCheck = [ ];
  });

  python = nixosPkgs.python313.override {
    packageOverrides = _: pyPrev: {
      mpmath = pyPrev.mpmath.overridePythonAttrs (_: rec {
        version = "1.3.0";
        doCheck = false;
        doInstallCheck = false;
        pythonImportsCheck = [ ];

        src = nixosPkgs.fetchPypi {
          pname = "mpmath";
          inherit version;
          hash = "sha256-eijrKpd00Ax7ySQRwZqJIJ1dp8TJqeInvoMwojoluR8=";
        };
      });
      gmpy2 = disablePythonChecks pyPrev.gmpy2;
      pplpy = disablePythonChecks pyPrev.pplpy;
      sympy = disablePythonChecks pyPrev.sympy;
    };
  };

  sagePkgs = nixosPkgs.extend (_: prev: {
    python3 = python;
    python313 = python;
    python3Packages = python.pkgs;
    python313Packages = python.pkgs;
  });

  sageBase = lib.getOutput "out" (
    (nixosPkgs.sage.override {
      withDoc = false;
      requireSageTests = false;
      pkgs = sagePkgs;
    }).overrideAttrs (_: {
      doCheck = false;
      doInstallCheck = false;
    })
  );

  sage = nixosPkgs.runCommand "ripper-sage-${nixosPkgs.sage.version}" {
    nativeBuildInputs = [ nixosPkgs.makeWrapper ];
  } ''
    mkdir -p "$out/bin"
    makeWrapper "${sageBase}/bin/sage" "$out/bin/sage"
  '';
in
{
  config.ripper.programs.packages = [
    sage
  ];
}
