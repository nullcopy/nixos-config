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

      # All .nix files in common/ are automatically applied to every host.
      # Drop a file there and it's picked up on the next rebuild — no manual
      # import needed in flake.nix or any host config.
      commonModules = builtins.map (name: ./common/${name}) (
        builtins.filter (name: nixpkgs.lib.hasSuffix ".nix" name) (
          builtins.attrNames (builtins.readDir ./common)
        )
      );

      # Each shell lives in its own file under ./devShells; add a new one by
      # dropping a file there and listing it below. There is no `default` —
      # always pick a language with `nix develop /path/to/this/flake#<lang>`.
      #
      # mkDevShell appends a shellHook that re-execs into zsh. `nix develop`
      # always spawns bashInteractive, dropping starship, aliases, completions,
      # etc; and it points $SHELL at that bash so child processes (e.g. nvim's
      # toggleterm via vim.o.shell) inherit a config-less shell. Overriding
      # $SHELL and exec'ing zsh fixes both. Centralizing the hook here keeps
      # per-language files focused on language tooling.
      mkDevShell =
        file:
        (import file { inherit pkgs system fenix; }).overrideAttrs (old: {
          shellHook = (old.shellHook or "") + ''
            export SHELL=${pkgs.zsh}/bin/zsh
            exec ${pkgs.zsh}/bin/zsh
          '';
        });
    in
    {
      formatter.${system} = pkgs.nixfmt;

      # devShells: one per language. To add another, drop e.g.
      # `./devShells/embedded-arm.nix` (a function taking { pkgs, system, fenix }
      # returning a `pkgs.mkShell { ... }`) and list it here. Enter with
      # `nix develop /path/to/flake#<name>`.
      devShells.${system} = {
        rust = mkDevShell ./devShells/rust.nix;
        python = mkDevShell ./devShells/python.nix;
        go = mkDevShell ./devShells/go.nix;
        c = mkDevShell ./devShells/c.nix;
        lua = mkDevShell ./devShells/lua.nix;
        nix = mkDevShell ./devShells/nix.nix;
        bash = mkDevShell ./devShells/bash.nix;
      };

      nixosConfigurations = {

        ## ----- wisp laptop config ----------------------------------------------
        wisp = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = commonModules ++ [
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

        ## ----- eregion desktop config ------------------------------------------
        eregion = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = commonModules ++ [
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
