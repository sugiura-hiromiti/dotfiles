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
          memory_graph = {
            legend_position = "bottom-left";
            cache_memory = true;
            #short_gpu_names=true;
          };
          network_graph = {
            legend_position = "bottom-left";
            use_binary_prefix = true;
          };
          processes = {
            columns = [
              "pid"
              "name"
              "user"
              "cpu%"
              "mem"
              "mem%"
              "gpu%"
              "gmem%"
              "state"
            ];
            default_sort = "mem";
            default_tree = true;
            tree_collapse = true;
          };
          disk = {
            use_binary_prefix = true;
          };
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
                      type = "batt";
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
            rate = 500;
            default_time_value = 30000;
            dot_marker = true;
            temperature_type = "k";
            battery = true;
          };
        };
      };
    };
  };
}
