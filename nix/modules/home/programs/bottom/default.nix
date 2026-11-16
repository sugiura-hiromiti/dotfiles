{ config, lib, ... }:
let
  cfg = config.dotfiles.programs.bottom;
in
{
  options.dotfiles.programs.bottom.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Whether to enable bottom.";
  };

  config = lib.mkIf cfg.enable {
    programs = {
      bottom = {
        enable = true;
        settings = {
          row = [
            {
              ratio = 1;
              child = [
                {
                  type = "proc";
                  default = true;
                }
              ];
            }
            {
              ratio = 2;
              child = [
                {
                  child = [
                    {
                      ratio = 2;
                      type = "cpu";
                    }
                    {
                      ratio = 1;
                      type = "mem";
                    }
                    {
                      ratio = 1;
                      type = "net";
                    }
                    {
                      ratio = 1;
                      type = "bat";
                    }
                  ];
                }
                {
                  child = [
                    { type = "temp_graph"; }
                    { type = "temp"; }
                  ];
                }
                {
                  child = [
                    {
                      type = "disk";
                    }
                    {
                      type = "disk_io_graph";
                    }
                  ];
                }
              ];
            }
          ];
          flags = {
            battery = true;
          };
        };
      };
    };
  };
}
