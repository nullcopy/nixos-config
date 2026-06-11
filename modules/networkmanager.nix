{ ... }:

## Interactive network management (wifi, VPNs, per-network config) — the right
## default for laptops/desktops. Servers with static or declarative networking
## skip this. users/<name>/system.nix only adds the "networkmanager" group
## when this module is imported, so accounts stay portable either way.
{
  networking.networkmanager.enable = true;
}
