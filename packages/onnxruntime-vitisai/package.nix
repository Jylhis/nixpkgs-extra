# nixpkgs' ONNX Runtime with the VitisAI execution provider wrapper enabled,
# for the AMD Ryzen AI NPU. Adapted from robcohen/nix-amd-npu (MIT), rev
# 8848c6f3, pkgs/onnxruntime-vitisai. Its version follows nixpkgs'
# onnxruntime, so it has no update script of its own.
#
# At run time the wrapper dlopens onnxruntime_vitisai_ep.so, which comes from
# AMD's Ryzen AI Software (unfree, not packaged here); put its directory on
# LD_LIBRARY_PATH.
{
  lib,
  onnxruntime,
}:

onnxruntime.overrideAttrs (oldAttrs: {
  pname = "onnxruntime-vitisai";

  # Stays on protobuf-lite like nixpkgs: with onnxruntime_USE_FULL_PROTOBUF
  # the test binaries register onnx-ml.proto twice and abort
  # (onnx/onnx#6094), which is why nixpkgs marks withFullProtobuf broken.
  cmakeFlags = oldAttrs.cmakeFlags ++ [
    (lib.cmakeBool "onnxruntime_USE_VITISAI" true)
  ];

  postPatch = (oldAttrs.postPatch or "") + ''
    # GCC 15 no longer pulls in <cstdint> transitively.
    for f in onnxruntime/core/providers/vitisai/imp/*.cc \
             onnxruntime/core/providers/vitisai/imp/*.h; do
      if [ -f "$f" ] && ! grep -q '#include <cstdint>' "$f"; then
        sed -i '1i #include <cstdint>' "$f"
      fi
    done

    # Normally injected from git metadata.
    sed -i 's/GIT_COMMIT_ID/"unknown"/g' onnxruntime/core/providers/vitisai/imp/global_api.cc
  '';

  # nixpkgs' tests exercise its own onnxruntime, not this variant.
  passthru =
    removeAttrs (oldAttrs.passthru or { }) [
      "updateScript"
      "tests"
    ]
    // {
      category = "AMD NPU";
      library = true;
    };

  meta = oldAttrs.meta // {
    description = "ONNX Runtime with the VitisAI execution provider for the AMD Ryzen AI NPU";
    sourceProvenance = [ lib.sourceTypes.fromSource ];
    maintainers = with lib.maintainers; [ jylhis ];
    platforms = [ "x86_64-linux" ];
    # About two hours to build: CI evaluates it but does not build it.
    hydraPlatforms = [ ];
  };
})
