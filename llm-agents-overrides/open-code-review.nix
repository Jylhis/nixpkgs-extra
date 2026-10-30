# open-code-review with git on the `ocr` wrapper's PATH and its Claude Code plugin (`passthru.claudeCodePlugin`).
{ final, prev }:
let
  inherit (final) lib git makeBinaryWrapper;
  ocr = prev.llm-agents.open-code-review;
in
ocr.overrideAttrs (old: {
  nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ makeBinaryWrapper ];

  # ocr shells out to git (>= 2.41) for every diff and code search; pin one
  # instead of relying on the caller's PATH.
  postInstall = (old.postInstall or "") + ''
    wrapProgram $out/bin/ocr --prefix PATH : ${lib.makeBinPath [ git ]}
  '';

  # The Claude Code plugin (review and delegate-review commands) ships in the
  # same tag, so CLI and plugin stay in step. Two patches: a review can run
  # past the Bash tool's 10-minute foreground limit, and the npm package
  # would shadow this one.
  passthru = old.passthru // {
    claudeCodePlugin = final.runCommand "open-code-review-claude-code-plugin" { } ''
      cp -r ${ocr.src}/plugins/open-code-review/claude-code $out
      chmod -R u+w $out
      substituteInPlace $out/commands/review.md \
        --replace-fail 'Set a 5-minute timeout.' \
          'Run it with the Bash tool'"'"'s run_in_background option and wait for it to finish: a review can take longer than the foreground timeout.' \
        --replace-fail 'install it by running `npm i -g @alibaba-group/open-code-review`.' \
          'stop and tell the user; it is installed with Nix, do not install it with npm.'
      substituteInPlace $out/commands/delegate-review.md \
        --replace-fail 'install it: `npm i -g @alibaba-group/open-code-review`.' \
          'stop and tell the user; it is installed with Nix, do not install it with npm.'
    '';
  };
})
