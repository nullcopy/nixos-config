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
}
