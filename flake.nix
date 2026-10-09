{
  description = "Euro-Office DesktopEditors from upstream releases with Wayland support";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
        euro-office-desktopeditors = pkgs.callPackage ./package.nix { };
      in
      {
        packages = {
          inherit euro-office-desktopeditors;
          default = euro-office-desktopeditors;
        };

        apps.default = {
          type = "app";
          program = "${euro-office-desktopeditors}/bin/euro-office-desktopeditors";
        };
      }
    )
    // {
      overlays.default = final: prev: {
        euro-office-desktopeditors = final.callPackage ./package.nix { };
      };
    };
}