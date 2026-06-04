{
  defaults = {
    theme = "light";
    session = "gui";
  };

  themes = {
    light = {
      theme = "light";
      variants = [
        "theme-light"
      ];
    };

    dark = {
      theme = "dark";
      variants = [
        "theme-dark"
      ];
    };
  };

  sessions = {
    gui = {
      session = "gui";
      hasGui = true;
      variants = [
        "desktop-integration"
        "session-gui"
      ];
    };

    tty = {
      session = "tty";
      hasGui = false;
      variants = [
        "session-tty"
      ];
    };
  };
}
