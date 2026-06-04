{ pkgs, ... }:
{
  services.pipewire = {
    jack = {
      enable = true;
    };
    wireplumber = {
      extraConfig = {
        "50-alsa-config" = {
          "monitor.alsa.rules" = [
            {
              matches = [ { "node.name" = "~alsa_output.*"; } ];
              actions = {
                update-props = {
                  "api.alsa.period-size" = 2048;
                  "api.alsa.headroom" = 8192;
                };
              };
            }
          ];
        };
      };
    };
    extraConfig = {
      pipewire = {
        "10-buffer" = {
          "context.properties" = {
            "default.clock.rate" = 48000;
            "default.clock.allowed-rates" = [
              44100
              48000
            ];
            "default.clock.quantum" = 512;
            "default.clock.min-quantum" = 256;
            "default.clock.max-quantum" = 1024;
          };
        };
      };
    };
  };

  environment.systemPackages = with pkgs; [
    pipewire.jack
    jack2
    jack-example-tools
  ];
}
