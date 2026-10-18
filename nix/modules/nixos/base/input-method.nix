{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.dotfiles.nixos.inputMethod;
in
{
  options.dotfiles.nixos.inputMethod.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Whether to configure the baseline fcitx5 input method.";
  };

  config = lib.mkIf cfg.enable {
    i18n.inputMethod = {
      enable = lib.mkDefault true;
      type = lib.mkDefault "fcitx5";
      fcitx5 = {
        waylandFrontend = lib.mkDefault true;
        addons = with pkgs; [
          fcitx5-skk
          fcitx5-gtk
        ];
        settings = {
          addons = {
            classicui.globalSection = {
              "Vertical Candidate List" = true;
              WheelForPaging = true;
              Font = "\"Monospace 10\"";
              MenuFont = "\"Monospace 10\"";
              TrayFont = "\"Monospace Oblique 10\"";
              TrayOutlineColor = "#000000";
              TrayTextColor = "#ffffff";
              PreferTextIcon = false;
              ShowLayoutNameInIcon = true;
              UseInputMethodLanguageToDisplayText = true;
              # Use the theme selected by Nix/Catppuccin for this configuration.
              UseDarkTheme = false;
              UseAccentColor = false;
              PerScreenDPI = false;
              ForceWaylandDPI = 0;
              EnableFractionalScale = true;
            };
            clipboard.globalSection = {
              TriggerKey = "";
              PastePrimaryKey = "";
              "Number of entries" = 3;
              IgnorePasswordFromPasswordManager = false;
              ShowPassword = false;
              ClearPasswordAfter = 30;
            };
            imselector.globalSection = {
              TriggerKey = "";
              TriggerKeyLocal = "";
              SwitchKey = "";
              SwitchKeyLocal = "";
            };
            keyboard = {
              globalSection = {
                PageSize = 5;
                EnableEmoji = true;
                EnableQuickPhraseEmoji = true;
                "Choose Modifier" = "Alt";
                EnableHintByDefault = false;
                "Hint Trigger" = "";
                "One Time Hint Trigger" = "";
                UseNewComposeBehavior = false;
                EnableLongPress = false;
              };
              sections = {
                PrevCandidate."0" = "Up";
                NextCandidate."0" = "Down";
                LongPressBlocklist = {
                  "0" = "konsole";
                  "1" = "org.kde.konsole";
                };
              };
            };
            mozc.globalSection = {
              InitialMode = "Hiragana";
              InputState = "\"Follow Global Configuration\"";
              Vertical = true;
              ExpandMode = "\"On Focus\"";
              PreeditCursorPositionAtBeginning = false;
              ExpandKey = "Control+Alt+H";
            };
            notifications.globalSection.HiddenNotifications = "";
            skk = {
              globalSection = {
                Rule = "custom";
                PunctuationStyle = "Japanese";
                InitialInputMode = "Hiragana";
                PageSize = 10;
                "Candidate Layout" = "Vertical";
                EggLikeNewLine = false;
                ShowAnnotation = true;
                CandidateChooseKey = "\"Digit (0,1,2,...)\"";
                NTriggersToShowCandWin = 0;
              };
              sections = {
                CandidatesPageUpKey."0" = "Page_Up";
                CandidatesPageDownKey."0" = "Next";
                CursorUp."0" = "Up";
                CursorDown."0" = "Down";
              };
            };
            wayland.globalSection."Allow Overriding System XKB Settings" = true;
            waylandim.globalSection = {
              DetectApplication = true;
              PreferKeyEvent = true;
              PersistentVirtualKeyboard = false;
            };
          };
          inputMethod = {
            GroupOrder = {
              "0" = "Default";
            };
            "Groups/0" = {
              Name = "Default";
              "Default Layout" = "us";
              DefaultIM = lib.mkDefault "skk";
            };
            "Groups/0/Items/0" = {
              Name = "keyboard-us";
            };
            "Groups/0/Items/1" = {
              Name = lib.mkDefault "skk";
            };
          };
          globalOptions = {
            Hotkey = {
              EnumerateWithTriggerKeys = true;
              ActivateKeys = "";
              DeactivateKeys = "";
              AltTriggerKeys = "";
              EnumerateForwardKeys = "";
              EnumerateBackwardKeys = "";
              EnumerateSkipFirst = false;
              EnumerateGroupForwardKeys = "";
              EnumerateGroupBackwardKeys = "";
              ModifierOnlyKeyTimeout = 250;
            };
            "Hotkey/TriggerKeys" = {
              "0" = "Control+space";
            };
            "Hotkey/PrevPage"."0" = "Page_Up";
            "Hotkey/NextPage"."0" = "Next";
            "Hotkey/PrevCandidate"."0" = "Up";
            "Hotkey/NextCandidate"."0" = "Down";
            "Hotkey/TogglePreedit"."0" = "Control+Alt+P";
            Behavior = {
              ActiveByDefault = true;
              resetStateWhenFocusIn = "No";
              ShareInputState = "All";
              PreeditEnabledByDefault = true;
              ShowInputMethodInformation = true;
              showInputMethodInformationWhenFocusIn = true;
              CompactInputMethodInformation = true;
              ShowFirstInputMethodInformation = true;
              DefaultPageSize = 5;
              OverrideXkbOption = false;
              CustomXkbOption = "";
              EnabledAddons = "";
              DisabledAddons = "";
              PreloadInputMethod = true;
              AllowInputMethodForPassword = false;
              ShowPreeditForPassword = false;
              AutoSavePeriod = 30;
            };
          };
        };
      };
    };
  };
}
