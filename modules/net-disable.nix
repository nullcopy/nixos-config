{
  config,
  lib,
  ...
}:

let
  cfg = config.custom.restrictInternet;
  mkRules =
    cmd:
    lib.concatStringsSep "\n" (
      lib.concatMap (user: [
        "${cmd} -A OUTPUT -o lo -m owner --uid-owner ${user} -j ACCEPT"
        "${cmd} -A OUTPUT -m owner --uid-owner ${user} -j DROP"
      ]) cfg
    );
  mkStopRules =
    cmd:
    lib.concatStringsSep "\n" (
      lib.concatMap (user: [
        "${cmd} -D OUTPUT -o lo -m owner --uid-owner ${user} -j ACCEPT || true"
        "${cmd} -D OUTPUT -m owner --uid-owner ${user} -j DROP || true"
      ]) cfg
    );
in
{
  options.custom.restrictInternet = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = "Users whose outbound internet traffic should be blocked (loopback exempted).";
  };

  config = lib.mkIf (cfg != [ ]) {
    networking.firewall.extraCommands = ''
      ${mkRules "iptables"}
      ${mkRules "ip6tables"}
    '';

    networking.firewall.extraStopCommands = ''
      ${mkStopRules "iptables"}
      ${mkStopRules "ip6tables"}
    '';
  };
}
