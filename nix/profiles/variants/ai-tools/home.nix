{
  iHaveAdhdSkill,
  interviewMeSkill,
  lib,
  pkgs,
  urdSkill,
  ...
}:
let
  iHaveAdhdOpenaiYaml = builtins.readFile "${iHaveAdhdSkill}/skills/i-have-adhd/agents/openai.yaml";
  iHaveAdhdNeedsImplicitPatch = lib.hasInfix "allow_implicit_invocation: false" iHaveAdhdOpenaiYaml;
  iHaveAdhdAllowsImplicit = lib.hasInfix "allow_implicit_invocation: true" iHaveAdhdOpenaiYaml;
  iHaveAdhdImplicit =
    assert iHaveAdhdNeedsImplicitPatch || iHaveAdhdAllowsImplicit;
    pkgs.runCommand "i-have-adhd-implicit-skill" { } ''
      cp -R ${iHaveAdhdSkill}/skills/i-have-adhd "$out"
      chmod -R u+w "$out"
      ${lib.optionalString iHaveAdhdNeedsImplicitPatch ''
        substituteInPlace "$out/agents/openai.yaml" \
          --replace-fail \
          "allow_implicit_invocation: false" \
          "allow_implicit_invocation: true"
      ''}
    '';

  interviewMeAlways = pkgs.writeTextDir "SKILL.md" (
    builtins.readFile "${interviewMeSkill}/skills/interview-me/SKILL.md"
    + ''

      ## Codex installation policy

      For this installation, apply the interview protocol at the beginning of
      every interactive task, even when the initial request appears clear,
      informational, or mechanical. This policy overrides the "When NOT to
      Use" conditions and loading constraints that would skip an interactive
      task based on its clarity or kind. Run the protocol once per task, not
      again on every follow-up turn. Skip it only when the user explicitly asks
      to skip or end it, or when higher-priority instructions require
      non-interactive execution.
    ''
  );
in
{
  dotfiles.features.aiTools.enable = lib.mkDefault true;

  programs.codex = {
    skills = {
      i-have-adhd = iHaveAdhdImplicit;
      interview-me = interviewMeAlways;
      urd = "${urdSkill}/skills/urd";
    };

    context = lib.mkAfter ''
      ## Required global skills

      - Invoke `$i-have-adhd` and apply it to the presentation of every
        user-facing response.
      - Invoke `$interview-me` at the beginning of every interactive task,
        even when the request initially appears clear. Complete its interview
        before planning, implementation, or the final answer. Do not restart
        the interview on each follow-up turn unless the intended outcome
        materially changes.
      - After the requirements are confirmed, invoke `$urd` and keep applying
        it throughout planning, implementation, and verification.
      - `$interview-me` and `$urd` are sequential, not concurrent. If `$urd`
        uncovers a change to the intended outcome, success criteria,
        constraints, or scope, return to `$interview-me`, reconfirm the intent,
        and then resume `$urd`.
      - Skip a skill only when the user explicitly requests it, or when a
        higher-priority instruction makes the skill inapplicable.
    '';
  };
}
