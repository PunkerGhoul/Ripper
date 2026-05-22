# Ripper

Ripper is a pure flake-based Home Manager profile for Debian and Arch Linux VMs,
with VMware as the primary target.

## Apply

Install Nix with flakes enabled, clone the repository, then run:

```bash
nix run .
```

The default app builds a small Go installer. The installer detects the current
Linux user, home directory, system architecture, distro family, and GPU strategy,
then writes that data to `local/install.nix`. Home Manager is applied from that
declaration with:

```bash
home-manager switch --flake path:$PWD#ripper -b backup
```

Useful explicit commands:

```bash
nix run .#init
nix run .#doctor
nix run .#switch
```

## Purity Model

Nix evaluation does not read environment variables, channels, or host state. The
only host detection happens in the Go installer before evaluation, and its output
is a normal Nix declaration in `local/install.nix`.

`local/` is intentionally ignored by Git. It is machine-local declaration and
state, not reusable module logic.

Optional local secrets and identity data live in `local/env.nix`. When the file
is absent, the flake uses empty safe defaults.

Reusable Nix code lives under `nix/`. The root `flake.nix` only exists as the
stable entrypoint required by `nix run .`.

## Graphics

The generated config uses `gpu.wrapper = "mesa";`. In VMware guests this is the
right pure path for SVGA/Mesa acceleration, including hosts whose physical GPU is
Nvidia. It also works for Intel, AMD, and Nouveau users on Debian and Arch.

nixGL auto-detection is intentionally not used because it depends on host driver
state during evaluation. For Nvidia passthrough, edit `local/install.nix` and
declare a pinned driver:

```nix
gpu = {
  wrapper = "nvidia";
  nvidia = {
    version = "550.120";
    sha256 = "sha256-...";
  };
};
```
