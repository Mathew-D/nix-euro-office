# nix-euro-office

This flake packages Euro-Office Desktop Editors from upstream GitHub Releases (not the old dev artifact path) and runs it in an FHS environment with Wayland support.

## What this package does

- Uses release artifacts from https://github.com/Euro-Office/DesktopEditors/releases
- Current packaged release: v9.3.5-2
- Prefers Wayland with X11 fallback via:
  - QT_QPA_PLATFORM=wayland;xcb
- Keeps compatibility launcher name:
  - euro-office-desktopeditors

## Build and run

From this repository root:

```bash
nix build .#euro-office-desktopeditors
nix run .#euro-office-desktopeditors
```

Run directly from GitHub (no local clone):

```bash
nix run github:mathew-d/nix-euro-office
```

## Add to your config

If you use a flake-based NixOS/Home Manager config, add this flake as an input and consume its package:

```nix
{
  inputs.euro-office = {
    url = "github:mathew-d/nix-euro-office";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, ... }@inputs: {
    # NixOS example
    nixosConfigurations.my-host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ({ pkgs, ... }: {
          environment.systemPackages = [
            inputs.euro-office.packages.${pkgs.system}.default
          ];
        })
      ];
    };
  };
}
```

Optional quick checks:

```bash
nix flake show
nix build .#euro-office-desktopeditors --dry-run
```

## Wayland notes

This package sets:

- QT_QPA_PLATFORM=wayland;xcb
- QT_STYLE_OVERRIDE=Fusion

That means it will try Wayland first, then fall back to X11 if needed.

## Fonts behavior

Euro-Office scans user-local fonts aggressively, and system fonts can be missed in containerized setups.

To make system fonts visible reliably, this package:

1. Copies system fonts from the host font tree into a cache directory with real files
2. Merges those with your existing user fonts
3. Bind-mounts the merged result to ~/.local/share/fonts inside the runtime sandbox

Effective merged font source path:

- ~/.cache/euro-office-desktopeditors/merged-local-fonts

Euro-Office font index/cache files are regenerated when the source stamp changes.

## If fonts do not update

1. Close all Euro-Office windows.
2. Remove the app font cache files:

```bash
rm -f ~/.local/share/euro-office/desktopeditors/data/fonts/AllFonts.js*
rm -f ~/.local/share/euro-office/desktopeditors/data/fonts/font_selection.bin
rm -f ~/.local/share/euro-office/desktopeditors/data/fonts/fonts.log
rm -f ~/.local/share/euro-office/desktopeditors/data/fonts/fonts_thumbnail*
```

3. Run again:

```bash
nix run .#euro-office-desktopeditors
```

## Updating to a newer release

Edit package.nix:

- version
- srcBySystem asset names (if changed upstream)
- srcBySystem hashes

Then validate:

```bash
nix build .#euro-office-desktopeditors --dry-run
```
