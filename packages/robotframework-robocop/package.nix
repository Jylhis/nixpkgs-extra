# Robocop, the Robot Framework linter and formatter, from the pure-Python
# wheel. Not in nixpkgs. Takes the caller's python package set, so a Robot
# Framework interpreter can include it next to its libraries:
# `python3.withPackages (ps: [ (callPackage ../robotframework-robocop
# { python3Packages = ps; }) ])`.
{
  lib,
  fetchPypi,
  fetchpatch,
  python3Packages,
  nix-update-script,
}:

let
  # Stopgap until nixpkgs carries robotframework's fix for isatty() on a
  # detached buffer, which fails its tests on Python 3.14
  # (robotframework/robotframework#5825). robotcode reuses it via passthru.
  robotframework = python3Packages.robotframework.overridePythonAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      (fetchpatch {
        url = "https://github.com/robotframework/robotframework/commit/ca249542582f2b5d69a409e32bc7e11967ff7237.patch";
        hash = "sha256-/Vc5SUPhJkamrJyfgl/9SZb1OiGTsbZMQHDDpizR0L4=";
      })
    ];
  });
in
python3Packages.buildPythonPackage (finalAttrs: {
  pname = "robotframework-robocop";
  version = "9.1.2";
  format = "wheel";

  src = fetchPypi {
    pname = "robotframework_robocop";
    inherit (finalAttrs) version;
    format = "wheel";
    dist = "py3";
    python = "py3";
    hash = "sha256-FSzRpmn06BU5JA/z9cVP/ZPRjJ+OwBJg0hAlS/nmnCw=";
  };

  dependencies = [
    robotframework
  ]
  ++ (with python3Packages; [
    jinja2
    msgpack
    pathspec
    platformdirs
    rich
    tomli-w
    typer
    typing-extensions
  ]);

  pythonImportsCheck = [ "robocop" ];

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    printf '*** Test Cases ***\nExample\n    Log    hello\n' > example.robot
    $out/bin/robocop check example.robot || [ $? -le 1 ]
    $out/bin/robocop format --check example.robot || [ $? -le 1 ]
    runHook postInstallCheck
  '';

  passthru = {
    inherit robotframework;
    category = "Developer tools";
    updateScript = nix-update-script { };
  };

  meta = {
    description = "Linter and formatter for Robot Framework";
    homepage = "https://github.com/MarketSquare/robotframework-robocop";
    changelog = "https://github.com/MarketSquare/robotframework-robocop/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.fromSource ];
    maintainers = with lib.maintainers; [ jylhis ];
    mainProgram = "robocop";
    platforms = lib.platforms.all;
  };
})
