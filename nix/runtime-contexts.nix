{
  defaults = {
    theme = "light";
    session = "gui";
  };

  themes = {
    light = {
      theme = "light";
      profiles = [
        "theme-light"
      ];
    };

    dark = {
      theme = "dark";
      profiles = [
        "theme-dark"
      ];
    };
  };

  sessions = {
    gui = {
      session = "gui";
      hasGui = true;
      profiles = [
        "desktop-integration"
        "session-gui"
      ];
    };

    tty = {
      session = "tty";
      hasGui = false;
      profiles = [
        "session-tty"
      ];
    };
  };
}
