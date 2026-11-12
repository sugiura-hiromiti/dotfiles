# DTM JACK compatibility migration

## Approved behavior

Keep `dotfiles.features.dtm.jack.enable` as the public capability switch while
replacing the deprecated `services.pipewire.jack.enable` implementation. Apply
PipeWire's JACK libraries to REAPER through its existing launcher. Supply
`pw-jack` for other JACK clients, as discussed with the user.

## Implementation

1. Add focused NixOS and Home Manager regression checks using real modules.
   Cover feature and child opt-outs, preservation of independently configured
   packages/programs, standalone Home Manager, and inheritance from NixOS.
   Run them against the existing implementation to confirm the failure.
2. In `nix/modules/nixos/features/dtm.nix`, provision `pipewire.jack` only while
   the JACK child is enabled. Keep the other configurable DTM packages. Request
   PipeWire audio through defaults and stop setting the deprecated option.
3. In `nix/modules/home/features/dtm.nix`, expose the same JACK child option.
   Default to the NixOS DTM/JACK selection when `osConfig` is available; otherwise
   default to Linux support. An explicit Home Manager setting may override this
   default. While enabled on Linux, install `pipewire.jack` and add its library
   to enabled REAPER's `programs.reaper.packages`. Feature/child opt-outs stop
   these contributions without disabling independently configured programs.
4. Register `dtm-home` and `dtm-nixos` in `nix/checks.nix`. Run the regression
   checks, formatting/lint checks, and the current host's complete derivation
   evaluation. Confirm the JACK deprecation warning disappears and that
   standalone Darwin still evaluates without PipeWire dependencies.
5. Request an independent review, address material findings, and report the
   verification results. Leave changes in the current shared workspace.

## Review focus

- A NixOS JACK opt-out reaches embedded Home Manager without changing generic
  configuration builders.
- Disabled features preserve independent package/program configuration.
- Linux-only package expressions remain lazy on Darwin.
- REAPER uses its existing launcher; no session-wide library path is added.
- Runtime audio routing requires a real session check after activation.
