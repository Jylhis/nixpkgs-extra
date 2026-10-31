# RobotCode, the Robot Framework language server, debugger and CLI, from the
# pure-Python PyPI wheels. Takes the caller's python package set so it can sit
# next to the Robot Framework libraries it imports:
# `python3.withPackages (ps: [ (callPackage ../robotcode { python3Packages = ps; }) ])`.
#
# Upstream is a monorepo of `robotcode-*` wheels in one split namespace, all
# pinned to one version; sub-wheels are exposed in passthru for nix-update.
{
  lib,
  fetchPypi,
  python3Packages,
  robotframework-robocop,
  nix-update-script,
}:

let
  version = "2.8.0";

  # The wheels under-declare sibling requirements and several require the
  # `robotcode` meta wheel, supplied only by the assembled package below, so
  # the per-wheel deps check is off and imports are checked once there.
  wheel =
    pname: hash: dependencies:
    python3Packages.buildPythonPackage {
      inherit pname version dependencies;
      format = "wheel";
      src = fetchPypi {
        pname = lib.replaceStrings [ "-" ] [ "_" ] pname;
        inherit version hash;
        format = "wheel";
        dist = "py3";
        python = "py3";
      };
      dontCheckRuntimeDeps = true;
      doCheck = false;
    };

  py = python3Packages;
  robocop = robotframework-robocop.override { python3Packages = py; };

  wheels = rec {
    core = wheel "robotcode-core" "sha256-3EnM6mj/8jyb27d4GqPhTyu8jzZWLPFQTd47NjBYYl4=" [
      py.typing-extensions
    ];
    plugin = wheel "robotcode-plugin" "sha256-Xr46nC2l8/Zu/P0nBXxnxiZB2R5zws52hOUujpjJwaM=" (
      with py;
      [
        click
        colorama
        pluggy
        rich
        tomli-w
      ]
    );
    robot = wheel "robotcode-robot" "sha256-2ZKTfS0vlJ8mexnQnrzoJabcBSPz+3pVaQuxSHSIw+Q=" [
      py.platformdirs
      py.robotframework
      core
    ];
    jsonrpc2 = wheel "robotcode-jsonrpc2" "sha256-XJBm3RSauM9jmG4w2+SzgCaAt+WGZuG8iReUFMhJKlc=" [
      core
    ];
    modifiers = wheel "robotcode-modifiers" "sha256-pGDCHe4JMPOdYoL/0qk8dtoTycFqdLBYw4fngroPzvg=" [
      py.robotframework
    ];
    analyze = wheel "robotcode-analyze" "sha256-Ha6cFJlDjEVxIRxFsUMBczI5eQ+eFBaXlh1yskZC/3M=" [
      plugin
      robot
    ];
    runner = wheel "robotcode-runner" "sha256-rsKl2biVfH/J+eTtYgPxrvboWIlanLpFFE3kv77N/os=" [
      modifiers
      plugin
      robot
    ];
    language-server =
      wheel "robotcode-language-server" "sha256-lbR43+VH+4V78yEoURfpxgXpaAM8oybEOeCqCRSf5/4="
        [
          analyze
          jsonrpc2
          robot
        ];
    debugger = wheel "robotcode-debugger" "sha256-q8OJqubO3kFved9Jz4QLbgIPLGxDvVcuJwDjB95gRfE=" [
      jsonrpc2
      runner
    ];
    repl = wheel "robotcode-repl" "sha256-55ZnFeIbCY5iHBw+QSnxmYE/GG1wBEqTFmdbcdjZPZ8=" [
      py.prompt-toolkit
      runner
    ];
    repl-server = wheel "robotcode-repl-server" "sha256-It5N1TQmoLfEswHYNdcDE4txJUYPLRnC5QZh59ropkM=" [
      jsonrpc2
      runner
    ];
  };
in
py.buildPythonPackage {
  pname = "robotcode";
  inherit version;
  format = "wheel";

  src = fetchPypi {
    pname = "robotcode";
    inherit version;
    format = "wheel";
    dist = "py3";
    python = "py3";
    hash = "sha256-ctjqmVUS6S65694zR7D+T1DwpOwn6rsMMU7hCLeY4VQ=";
  };

  # The `all` extra: every subcommand plus robocop for linting.
  dependencies = lib.attrValues wheels ++ [
    robocop
    py.docutils
    py.pyyaml
  ];

  pythonImportsCheck = [
    "robotcode.analyze"
    "robotcode.cli"
    "robotcode.core"
    "robotcode.debugger"
    "robotcode.jsonrpc2"
    "robotcode.language_server"
    "robotcode.modifiers"
    "robotcode.plugin"
    "robotcode.repl"
    "robotcode.repl_server"
    "robotcode.robot"
    "robotcode.runner"
  ];

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    export HOME=$TMPDIR
    mkdir suite
    printf '*** Test Cases ***\nExample\n    Log    hello\n' > suite/example.robot
    $out/bin/robotcode --version
    $out/bin/robotcode discover tests suite | grep -q Example
    $out/bin/robotcode analyze code suite
    runHook postInstallCheck
  '';

  passthru = wheels // {
    category = "Developer tools";
    updateScript = nix-update-script {
      extraArgs = lib.concatMap (w: [
        "--subpackage"
        w
      ]) (lib.attrNames wheels);
    };
  };

  meta = {
    description = "Language server, debugger and CLI for Robot Framework";
    homepage = "https://robotcode.io";
    changelog = "https://github.com/robotcodedev/robotcode/releases/tag/v${version}";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.fromSource ];
    maintainers = with lib.maintainers; [ jylhis ];
    mainProgram = "robotcode";
    platforms = lib.platforms.all;
  };
}
