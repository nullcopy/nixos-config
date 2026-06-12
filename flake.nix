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
      nixpkgs,
      home-manager,
      fenix,
      ...
    }:
    let
      lib = nixpkgs.lib;

      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      # mkHost assembles a machine from three layers:
      #
      #   modules/core.nix    baseline every machine gets (headless-safe)
      #   hosts/<hostname>/   hardware + host services; the host also picks its
      #                       role modules (audio, networkmanager, greeter, ...)
      #                       via imports in its configuration.nix
      #   users/<user>/       per-user account (system.nix), home-manager config
      #                       (home.nix), and — only on graphical hosts, only if
      #                       the user defines one — their desktop (desktop.nix)
      #
      # `graphical = false` builds a headless host: users keep their full CLI
      # homes, but every users/<user>/desktop.nix is skipped, so no compositor
      # or GUI package enters the closure. A headless host's configuration.nix
      # also imports no greeter from modules/greeters/.
      mkHost =
        {
          hostname,
          system ? "x86_64-linux",
          users ? [ ],
          graphical ? true,
          extraModules ? [ ],
        }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [
            ./modules/core.nix
            ./hosts/${hostname}/configuration.nix
            { networking.hostName = hostname; }
            # Enforce the headless invariant mechanically: `graphical = false`
            # skips users' desktop.nix, but the greeter import lives in the
            # host's own configuration.nix — catch the mismatch at eval time
            # instead of shipping a login screen on a server.
            (
              { config, ... }:
              {
                assertions = [
                  {
                    assertion = graphical || !config.services.greetd.enable;
                    message = "Host ${hostname} is declared headless (graphical = false) but enables a greeter; remove the modules/greeters/* import from hosts/${hostname}/configuration.nix.";
                  }
                ];
              }
            )
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = { inherit inputs; };
              # If home-manager wants to manage a file that already exists
              # (e.g. a hand-written ~/.zshrc on first deploy), move it aside
              # with this suffix instead of aborting the activation.
              home-manager.backupFileExtension = "hm-backup";
            }
          ]
          ++ lib.concatMap (
            user:
            [
              ./users/${user}/system.nix
              { home-manager.users.${user} = import ./users/${user}/home.nix; }
            ]
            ++ lib.optional (graphical && builtins.pathExists ./users/${user}/desktop.nix) (
              ./users/${user}/desktop.nix
            )
          ) users
          ++ extraModules;
        };

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
      #
      # The exec is guarded: it only fires in an *interactive* bash ($- contains
      # "i"). Non-interactive entries — `nix develop .#rust -c cargo build`,
      # direnv's `use flake` — run the hook in a non-interactive bash, where an
      # unconditional exec would swallow the command they came to run.
      # IN_NIX_SHELL_EXEC prevents a nested `nix develop` from re-exec looping.
      mkDevShell =
        file:
        (import file { inherit pkgs system fenix; }).overrideAttrs (old: {
          shellHook = (old.shellHook or "") + ''
            case $- in
              *i*)
                if [ -z "''${IN_NIX_SHELL_EXEC:-}" ]; then
                  export IN_NIX_SHELL_EXEC=1
                  export SHELL=${pkgs.zsh}/bin/zsh
                  exec ${pkgs.zsh}/bin/zsh
                fi
                ;;
            esac
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

        ## ----- wisp laptop ------------------------------------------------------
        wisp = mkHost {
          hostname = "wisp";
          users = [ "nullcopy" ];
        };

        ## A headless host would look like:
        ##   somehost = mkHost {
        ##     hostname = "somehost";
        ##     users = [ "nullcopy" ];
        ##     graphical = false;
        ##   };
      };
    };
}
