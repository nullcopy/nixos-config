{ ... }:

## Pipewire audio stack. Imported by any host with speakers/mics — laptops,
## desktops, media boxes. Headless servers skip it.
{
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
}
