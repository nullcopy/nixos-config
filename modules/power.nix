{ ... }:

## Laptop-style power management: battery/AC profiles + battery reporting.
{
  services.power-profiles-daemon.enable = true;
  services.upower.enable = true;
}
