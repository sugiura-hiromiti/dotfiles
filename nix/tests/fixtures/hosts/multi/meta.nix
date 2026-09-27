{
  system = "aarch64-linux";
  targets = [
    "home"
    "nixos"
  ];
  deployments = {
    pending.modules = [ ];
    ready.modules = [ ];
  };
  accounts = {
    primary = "admin";
    users.admin.uid = 1000;
  };
  runtime = {
    themes = [
      "dark"
      "light"
    ];
    sessions = [
      "tty"
      "gui"
    ];
    defaultTheme = "dark";
    defaultSession = "tty";
    targetAxes = {
      theme = true;
      session = true;
    };
  };
}
