{
  config,
  lib,
  pkgs,
  ...
}:

# NymVPN daemon (nym-vpnd) + CLI client (nym-vpnc).
#
# Not in nixpkgs — the `nym` package there is only the mixnet infrastructure
# binaries — so this packages the official prebuilt release binaries from
# https://github.com/nymtech/nym-vpn-client/releases instead.
#
# First-time setup (needs an account from https://nym.com):
#   nym-vpnc account store    # paste the account mnemonic when prompted
#
# Daily use (tailscale auto-connects at login via the tailscale-up user
# service; stop it first so the two tunnels don't fight over routes/DNS):
#   systemctl --user stop tailscale-up && nym-vpnc connect
#   nym-vpnc status
#   nym-vpnc disconnect && systemctl --user start tailscale-up
#
# To update: bump `version`, then replace `hash` with the value from the
# release's hashes (or let the rebuild fail once and copy the hash nix prints).

let
  version = "2026.10.0";

  nym-vpn-core = pkgs.stdenv.mkDerivation {
    pname = "nym-vpn-core";
    inherit version;

    src = pkgs.fetchurl {
      url = "https://github.com/nymtech/nym-vpn-client/releases/download/nym-vpn-core-v${version}/nym-vpn-core-v${version}_linux_x86_64.tar.gz";
      hash = "sha256-k5q4MtwiS2J8Q7bCpWIHO6XbzVMFeavjvhOtH9ITbJs=";
    };

    sourceRoot = "nym-vpn-core-v${version}_linux_x86_64";

    # The prebuilt binaries target generic Linux; autoPatchelfHook rewrites
    # their ELF interpreter/rpath to nix store paths. nym-vpnd links against
    # libmnl/libnftnl (firewall rules), libdbus (DNS via NetworkManager /
    # systemd-resolved), and libgcc_s (stdenv.cc.cc.lib) — checked with
    # readelf -d.
    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    buildInputs = with pkgs; [
      dbus
      libmnl
      libnftnl
      stdenv.cc.cc.lib
    ];

    installPhase = ''
      runHook preInstall
      install -Dm755 nym-vpnd nym-vpnc -t $out/bin
      runHook postInstall
    '';

    meta = {
      description = "NymVPN daemon and CLI client (official prebuilt binaries)";
      homepage = "https://nym.com";
      license = lib.licenses.gpl3Only;
      platforms = [ "x86_64-linux" ];
    };
  };

  # nym-vpnd authorizes clients on its unix socket through polkit, using an
  # action id baked into the binary. Polkit only recognizes actions declared
  # in a .policy file, so ship upstream's (the .deb relies on the distro's
  # /usr/share/polkit-1/actions; on NixOS, packages in systemPackages get
  # share/polkit-1/actions linked to where polkit looks). Verbatim from
  # nym-vpn-core/crates/nym-ipc/.pkg/com.nymvpn.vpnd.unix-access.policy.
  nym-vpnd-polkit-policy = pkgs.writeTextFile {
    name = "nym-vpnd-polkit-policy";
    destination = "/share/polkit-1/actions/com.nymvpn.vpnd.unix-access.policy";
    text = ''
      <?xml version="1.0" encoding="UTF-8"?>
      <policyconfig>
        <action id="com.nymvpn.vpnd.unix-access">
          <description>Connect via unix socket</description>
          <message>Authentication is required to connect to the daemon</message>

          <defaults>
            <allow_any>auth_admin</allow_any>
            <allow_inactive>auth_admin</allow_inactive>
            <allow_active>auth_self</allow_active>
          </defaults>
        </action>
      </policyconfig>
    '';
  };
in
{
  ## ----- packages ------------------------------------------------------------
  environment.systemPackages = [
    nym-vpn-core
    nym-vpnd-polkit-policy
  ];

  ## ----- polkit --------------------------------------------------------------
  # Grant wheel users daemon access without an auth prompt: the upstream
  # default of auth_self needs a polkit authentication agent, which this
  # niri setup doesn't run.
  security.polkit = {
    enable = true;
    extraConfig = ''
      polkit.addRule(function (action, subject) {
        if (action.id == "com.nymvpn.vpnd.unix-access" &&
            subject.isInGroup("wheel")) {
          return polkit.Result.YES;
        }
      });
    '';
  };

  ## ----- daemon --------------------------------------------------------------
  # Mirrors the unit shipped in the official .deb, plus an explicit PATH:
  # the daemon shells out to these network tools at tunnel setup, and on
  # NixOS they aren't in a system service's default PATH (without them it
  # fails with Error(TunDevice)). Running the daemon is harmless on its own;
  # like tailscaled, it creates no tunnel until a client asks it to connect.
  systemd.services.nym-vpnd = {
    description = "NymVPN daemon";
    wantedBy = [ "multi-user.target" ];
    before = [ "network-online.target" ];
    after = [
      "NetworkManager.service"
      "systemd-resolved.service"
    ];
    path = with pkgs; [
      iproute2
      iptables
      nftables
      coreutils
    ];
    startLimitBurst = 6;
    startLimitIntervalSec = 24;
    serviceConfig = {
      ExecStart = "${nym-vpn-core}/bin/nym-vpnd -v run-as-service";
      Restart = "always";
      RestartSec = 2;
    };
  };
}
