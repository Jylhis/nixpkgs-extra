# MLIR-based toolchain for the AMD AI Engine (NPU), repackaged from the
# upstream release wheel. Adapted from robcohen/nix-amd-npu (MIT), rev
# 8848c6f3, pkgs/mlir-aie.
{
  lib,
  stdenv,
  fetchurl,
  fetchFromGitHub,
  nix-update-script,
  python312,
  autoPatchelfHook,
  makeWrapper,
  zlib,
  ncurses,
  libxml2,
  unzip,
}:

let
  # The bindings import aie.extras.dialects, which the wheel does not ship.
  # Since 1.4 upstream installs eudsl-python-extras (python/requirements.txt)
  # instead of this fork; this older copy still provides the modules
  # aie.iron imports. Pure Python.
  mlirPythonExtras = fetchFromGitHub {
    owner = "erwei-xilinx";
    repo = "mlir-python-extras";
    rev = "2de5fda27f018eca9defe41a79c702c3f1eb9033";
    hash = "sha256-DVYWaxH4dBG0Xjs86ol8l3eHf1lkWwVER1swujHw4DQ=";
  };

  # The wheel's Requires-Dist (minus the `dataclasses` backport) plus what
  # aie.extras needs. nixpkgs only has numpy 2 (wheel asks < 2); the bindings
  # import with it.
  python = python312.withPackages (
    ps: with ps; [
      pyyaml
      aiofiles
      numpy
      rich
      ml-dtypes
      bytecode
      cloudpickle
    ]
  );
in
stdenv.mkDerivation (finalAttrs: {
  pname = "mlir-aie";
  version = "1.4.5";

  src = fetchurl {
    url = "https://github.com/Xilinx/mlir-aie/releases/download/v${finalAttrs.version}/mlir_aie-${finalAttrs.version}-cp312-cp312-manylinux_2_35_x86_64.whl";
    hash = "sha256-25WILqxxo5kNUbrhX6EeB+uL+FSO00OOwwl19MGiOSs=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    unzip
  ];

  buildInputs = [
    stdenv.cc.cc.lib
    zlib
    ncurses
    libxml2
  ];

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    site=$out/lib/${python312.libPrefix}/site-packages
    mkdir -p $site
    unzip -q $src -d $site
    chmod -R u+w $out
    # Merge into the wheel's aie/extras (it carries only meta.py and
    # types.py from the MLIR bindings, which the fork does not touch).
    cp -r --no-clobber ${mlirPythonExtras}/mlir/extras/. $site/mlir_aie/python/aie/extras/
    chmod -R u+w $site/mlir_aie/python/aie/extras

    # txn2mlir.py imports `aie`, found only via aie.pth when
    # site-packages is a site dir; run it with an interpreter that has the
    # wheel's dependencies, PYTHONPATH and the native tools on PATH.
    mkdir -p $out/bin
    for tool in $site/mlir_aie/bin/*; do
      [ -x "$tool" ] || continue
      name=$(basename "$tool")
      if [[ $name == *.py ]]; then
        makeWrapper ${python.interpreter} $out/bin/$name \
          --add-flags "$tool" \
          --prefix PYTHONPATH : $site/mlir_aie/python \
          --prefix PATH : $site/mlir_aie/bin
      else
        ln -s "$tool" $out/bin/$name
      fi
    done

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    $out/bin/aiecc --help >/dev/null
    $out/bin/aiecc --version
    $out/bin/txn2mlir.py --help >/dev/null
    runHook postInstallCheck
  '';

  passthru = {
    category = "AMD NPU";
    updateScript = nix-update-script { };
  };

  # Only the txn2mlir.py wrapper gets the Python dependencies;
  # importing `aie` (incl. aie.iron) elsewhere needs mlir_aie/python on
  # PYTHONPATH and the same packages.
  meta = {
    description = "MLIR-based toolchain for the AMD AI Engine";
    homepage = "https://github.com/Xilinx/mlir-aie";
    changelog = "https://github.com/Xilinx/mlir-aie/releases/tag/v${finalAttrs.version}";
    # mlir-aie, its LLVM/MLIR, XRT, bootgen and mlir-python-extras are
    # Apache 2.0 (LLVM with the LLVM exception); the bundled aie-rt driver
    # (libxaienginecdo) is MIT.
    license = with lib.licenses; [
      asl20
      llvm-exception
      mit
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    maintainers = with lib.maintainers; [ jylhis ];
    mainProgram = "aie-opt";
    platforms = [ "x86_64-linux" ];
  };
})
