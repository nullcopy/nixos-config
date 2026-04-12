{ config, pkgs, ... }:

let
  tailscale = "${pkgs.tailscale}/bin/tailscale";
  sudo = "/run/wrappers/bin/sudo";

  # Private values (login server URL, exit node IP) are read at service-start
  # time from a plain env file, so they never enter the repo or the nix store.
  # Populate the file before the first rebuild:
  #   mkdir -p ~/.config/tailscale
  #   cat > ~/.config/tailscale/connect.env <<EOF
  #   TAILSCALE_LOGIN_SERVER=https://your.headscale.example
  #   TAILSCALE_EXIT_NODE=100.64.0.1
  #   EOF
  #   chmod 600 ~/.config/tailscale/connect.env
  envFile = "$HOME/.config/tailscale/connect.env";

  tailscaleUp = pkgs.writeShellScript "tailscale-up" ''
    set -euo pipefail
    if [ ! -r "${envFile}" ]; then
      echo "tailscale-up: missing ${envFile}" >&2
      exit 1
    fi
    set -a; . "${envFile}"; set +a
    exec ${sudo} -n ${tailscale} up \
      --login-server="$TAILSCALE_LOGIN_SERVER" \
      --exit-node="$TAILSCALE_EXIT_NODE"
  '';
in
{
  home.packages = [ pkgs.tailscale ];

  # First-time setup: headscale auth is interactive. After populating the env
  # file and running nixos-rebuild switch, run
  #   sudo tailscale up --login-server=<your server> --exit-node=<your node>
  # once and complete the auth URL. Every login after that re-ups via the
  # service below.
  systemd.user.services.tailscale-up = {
    Unit = {
      Description = "Connect tailscale with configured exit node on login";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };

    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${tailscaleUp}";
      ExecStop = "${sudo} -n ${tailscale} down";
    };

    Install.WantedBy = [ "default.target" ];
  };
}
