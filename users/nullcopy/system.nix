{
  config,
  lib,
  pkgs,
  ...
}:

## nullcopy's system-side account, imported by every host that lists this user
## in its mkHost `users`. Host-independent: group membership degrades
## gracefully on hosts that don't run NetworkManager.
{
  programs.zsh.enable = true; # system-level so zsh is in /etc/shells

  users.users.nullcopy = {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = [
      "wheel"
    ]
    ++ lib.optional config.networking.networkmanager.enable "networkmanager"
    ++ [
      "audio"
      "video"
    ];
  };

  # Passwordless sudo for the tailscale binary only. The login-time
  # tailscale-up user service (./tailscale.nix) runs `sudo -n tailscale ...`;
  # `-n` fails rather than prompts, and wheel requires a password by default,
  # so without this rule the unit fails every login. A bare command path (no
  # args spec) permits any arguments; everything else still prompts as usual.
  # extraRules are emitted after the default wheel rule, and in sudoers the
  # last matching rule wins.
  security.sudo.extraRules = [
    {
      users = [ "nullcopy" ];
      commands = [
        {
          command = "${pkgs.tailscale}/bin/tailscale";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}
