inputs@{ self, nixpkgs, home-manager, nixgl, nur, ... }:
let
  supportedSystems = [
    "x86_64-linux"
    "aarch64-linux"
  ];

  formatterSystems = supportedSystems ++ [
    "x86_64-darwin"
    "aarch64-darwin"
  ];

  forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
  forAllFormatterSystems = nixpkgs.lib.genAttrs formatterSystems;

  localInstallPath = ../local/install.nix;
  hasLocalInstall = builtins.pathExists localInstallPath;

  installConfig =
    if hasLocalInstall then
      import localInstallPath
    else
      null;

  localEnvPath = ../local/env.nix;

  defaultEnv = {
    github = {
      name = "";
      email = "";
      signingKey = "";
    };
  };

  envConfig = nixpkgs.lib.recursiveUpdate defaultEnv (
    if builtins.pathExists localEnvPath then
      import localEnvPath
    else
      { }
  );

  mkPkgs = system:
    import nixpkgs {
      inherit system;

      config.allowUnfree = true;

      overlays = [
        nur.overlays.default
      ];
    };

  mkNixGLCommand = system: pkgs: gpu:
    let
      wrapper = gpu.wrapper or "mesa";
      packages = nixgl.packages.${system};
    in
    if wrapper == "mesa" then
      "${packages.nixGLIntel}/bin/nixGLIntel"
    else if wrapper == "nvidia" then
      let
        nvidia = gpu.nvidia or { };

        version =
          nvidia.version
            or (throw "gpu.nvidia.version is required for pure Nvidia nixGL");

        sha256 =
          nvidia.sha256
            or (throw "gpu.nvidia.sha256 is required for pure Nvidia nixGL");

        nixglPkgs = import nixgl {
          inherit pkgs;

          nvidiaVersion = version;
          nvidiaHash = sha256;

          enable32bits = system == "x86_64-linux";
          enableIntelX86Extensions = system == "x86_64-linux";
        };
      in
      "${nixglPkgs.nixGLCommon nixglPkgs.nixGLNvidia}/bin/nixGL"
    else
      throw "Unsupported gpu.wrapper: ${wrapper}";

  mkHome = cfg:
    let
      system = cfg.system;
      pkgs = mkPkgs system;
    in
    home-manager.lib.homeManagerConfiguration {
      inherit pkgs;

      modules = [ ./home.nix ];

      extraSpecialArgs = {
        inherit inputs;
        inherit (cfg) username homeDirectory stateVersion;

        env = envConfig;
        installConfig = cfg;

        unstable = pkgs;

        nixGLCommand = mkNixGLCommand system pkgs (cfg.gpu or { });
      };
    };

  mkInstallerPackage = system:
  let
    pkgs = mkPkgs system;

    buildGoModule = pkgs.buildGoModule.override {
      go = pkgs.go_1_26;
    };

  in
  buildGoModule {
    pname = "ripper-installer";
    version = "1.0.0";

    src = ../installer;

    subPackages = [ "cmd/ripper" ];

    vendorHash = null;

    doCheck = false;
  };

  mkInstallerApp = system: command:
    let
      pkgs = mkPkgs system;

      installer = mkInstallerPackage system;

      app = pkgs.writeShellApplication {
        name = "ripper-${command}";

        runtimeInputs = [
          home-manager.packages.${system}.home-manager
          pkgs.coreutils
          pkgs.nix
          pkgs.zsh
        ];

        text = ''
          set -euo pipefail

          repo_root="''${RIPPER_REPO_ROOT:-}"

          if [ -n "$repo_root" ] && [ -f "$repo_root/flake.nix" ]; then
            repo_root="$(cd "$repo_root" && pwd -P)"
          elif [ -f "$PWD/flake.nix" ]; then
            repo_root="$(cd "$PWD" && pwd -P)"
          elif [ -f "$PWD/../flake.nix" ]; then
            repo_root="$(cd "$PWD/.." && pwd -P)"
          else
            echo "Could not locate the Ripper project root. Run nix from the repository." >&2
            exit 1
          fi

          export RIPPER_REPO_ROOT="$repo_root"

          export RIPPER_HOME_MANAGER_BIN="${home-manager.packages.${system}.home-manager}/bin/home-manager"

          export RIPPER_NIX_BIN="${pkgs.nix}/bin/nix"

          exec ${installer}/bin/ripper ${command} "$@"
        '';
      };
    in
    {
      type = "app";
      program = "${app}/bin/ripper-${command}";
    };

in
{
  homeConfigurations =
    if hasLocalInstall then
      {
        ripper = mkHome installConfig;
      }
    else
      { };

  packages = forAllSystems (system: {
    default = mkInstallerPackage system;
  });

  apps = forAllSystems (system: {
    default = mkInstallerApp system "switch";

    apply = mkInstallerApp system "switch";

    switch = mkInstallerApp system "switch";

    init = mkInstallerApp system "init";

    doctor = mkInstallerApp system "doctor";
  });

  formatter = forAllFormatterSystems (
    system: (mkPkgs system).nixpkgs-fmt
  );
}