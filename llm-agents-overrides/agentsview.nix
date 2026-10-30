# agentsview with its `cmd/agentsview` Go tests run at build time (llm-agents skips them).
{ final, prev }:
prev.llm-agents.agentsview.overrideAttrs (old: {
  doCheck = true;
  # The tests create git repositories and write config under HOME.
  nativeCheckInputs = (old.nativeCheckInputs or [ ]) ++ [ final.git ];
  preCheck = (old.preCheck or "") + ''
    export HOME=$TMPDIR
  '';
  # Only subPackages (cmd/agentsview) is tested; -short skips its slow cases.
  checkFlags = (old.checkFlags or [ ]) ++ [ "-short" ];
})
