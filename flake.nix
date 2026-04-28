{
  description = "My NixOS Configuration Flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    noctalia = {
      url = "github:noctalia-dev/noctalia-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      noctalia,
      fenix,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      # Default Rust toolchain — used by this flake's devShell and intended as
      # the baseline for ad-hoc work. Per-project flakes should pin their own
      # toolchain (e.g. via rust-toolchain.toml + fenix.fromToolchainFile).
      rustToolchain = fenix.packages.${system}.combine [
        fenix.packages.${system}.stable.cargo
        fenix.packages.${system}.stable.rustc
        fenix.packages.${system}.stable.rustfmt
        fenix.packages.${system}.stable.clippy
        fenix.packages.${system}.stable.rust-src
        fenix.packages.${system}.stable.rust-analyzer
      ];
    in
    {
      formatter.${system} = pkgs.nixfmt;

      # `nix develop` here (or via direnv `use flake`) puts cargo, rustc,
      # rustfmt, clippy, and rust-analyzer on PATH. Launch `nvim` from inside
      # this shell so its rust-analyzer matches the project's rustfmt/clippy.
      devShells.${system}.default = pkgs.mkShell {
        packages = [ rustToolchain ];
      };

      nixosConfigurations = {

        ## ----- wisp laptop config ----------------------------------------------
        wisp = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [
            ./common/configuration.nix
            ./hosts/wisp/configuration.nix
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = { inherit inputs; };
              home-manager.users.nullcopy = import ./users/nullcopy/configuration.nix;
            }
          ];
        };
      };
    };
}
