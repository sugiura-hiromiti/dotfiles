{
  lib,
  pkgs,
}:
let
  dprintSettings = {
    lineWidth = 100;
    useTabs = true;
    typescript = {
      quoteStyle = "alwaysSingle";
      quoteProps = "asNeeded";
      useBraces = "always";
      bracePosition = "sameLineUnlessHanging";
      singleBodyPosition = "sameLine";
      trailingCommas = "always";
      operatorPosition = "nextLine";
      "binaryExpression.linePerExpression" = true;
      "memberExpression.linePerExpression" = true;
      "enumDeclaration.memberSpacing" = "newLine";
      semiColons = "always";
    };
    markdown = {
      textWrap = "maintain";
      emphasisKind = "asterisks";
    };
    yaml = {
      quotes = "preferSingle";
      formatComments = true;
      indentWidth = 2;
    };
    plugins = pkgs.dprint-plugins.getPluginList (
      plugins: with plugins; [
        dprint-plugin-json
        dprint-plugin-markdown
        dprint-plugin-typescript
        g-plane-pretty_yaml
      ]
    );
  };

  styluaSettings = {
    indent_width = 3;
    quote_style = "AutoPreferSingle";
    call_parentheses = "None";
    collapse_simple_statement = "Always";
    sort_requires.enabled = true;
  };

  dprintConfig = (pkgs.formats.json { }).generate "dprint.json" dprintSettings;
  styluaConfig = (pkgs.formats.toml { }).generate "stylua.toml" styluaSettings;

  dprintPackage = pkgs.writeShellApplication {
    name = "dprint";
    text = ''
      exec ${lib.getExe pkgs.dprint} --config ${dprintConfig} "$@"
    '';
  };

  styluaPackage = pkgs.writeShellApplication {
    name = "stylua";
    text = ''
      exec ${lib.getExe pkgs.stylua} --config-path ${styluaConfig} "$@"
    '';
  };
in
{
  dprint = {
    settings = dprintSettings;
    configFile = dprintConfig;
    package = dprintPackage;
  };

  stylua = {
    settings = styluaSettings;
    configFile = styluaConfig;
    package = styluaPackage;
  };

  editorTools = pkgs.symlinkJoin {
    name = "dotfiles-formatter-tools";
    paths = [
      dprintPackage
      styluaPackage
    ];
  };
}
