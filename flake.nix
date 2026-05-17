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

      # Each shell lives in its own file under ./devShells; add a new one by
      # dropping a file there and listing it below. Enter with
      # `nix develop /path/to/this/flake` (or `#<name>` for a non-default).
      mkDevShell = file: import file { inherit pkgs system fenix; };
    in
    {
      formatter.${system} = pkgs.nixfmt;

      # devShells: each entry sources a file under ./devShells. To add a
      # new shell, drop e.g. `./devShells/embedded-arm.nix` (a function
      # taking { pkgs, system, fenix }) and list it here as
      # `embedded-arm = mkDevShell ./devShells/embedded-arm.nix;`. Enter
      # with `nix develop /path/to/flake#embedded-arm`; the unnamed
      # `default` is what `nix develop /path/to/flake` picks up.
      devShells.${system} = {
        default = mkDevShell ./devShells/default.nix;
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

        ## ----- eregion laptop config -------------------------------------------
        eregion = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [
            ./common/configuration.nix
            ./hosts/eregion/configuration.nix
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = { inherit inputs; };
              home-manager.users.nullcopy = import ./users/nullcopy/configuration.nix;
              home-manager.users.vbug = import ./users/vbug/configuration.nix;
              home-manager.users.zed = import ./users/zed/configuration.nix;
            }
          ];
        };

      };
    };
}
