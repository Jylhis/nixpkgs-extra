# Robocop, the Robot Framework linter and formatter, from the pure-Python
# wheel. Not in nixpkgs. Takes the caller's python package set, so a Robot
# Framework interpreter can include it next to its libraries:
# `python3.withPackages (ps: [ (callPackage ../robotframework-robocop
# { python3Packages = ps; }) ])`.
{
  lib,
  fetchPypi,
  python3Packages,
  nix-update-script,
}:

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

  dependencies = with python3Packages; [
    jinja2
    msgpack
    pathspec
    platformdirs
    rich
    robotframework
    tomli-w
    typer
    typing-extensions
  ];

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
