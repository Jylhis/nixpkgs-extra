# Python bindings for onnxruntime-vitisai: nixpkgs' Python onnxruntime
# package, installed from the wheel that onnxruntime-vitisai builds. Adapted
# from robcohen/nix-amd-npu (MIT), rev 8848c6f3,
# pkgs/python-onnxruntime-vitisai. Its version follows onnxruntime-vitisai,
# so it has no update script of its own.
{
  lib,
  python3Packages,
  onnxruntime-vitisai,
}:

(python3Packages.onnxruntime.override { onnxruntime = onnxruntime-vitisai; }).overridePythonAttrs
  (oldAttrs: {
    pname = "onnxruntime-vitisai";

    # The wheel normally carries the VitisAI provider wrapper; copy it from the
    # C++ build when it does not.
    postFixup = (oldAttrs.postFixup or "") + ''
      capi=$(echo $out/lib/python*/site-packages/onnxruntime/capi)
      if [ ! -f "$capi/libonnxruntime_providers_vitisai.so" ]; then
        cp ${onnxruntime-vitisai}/lib/libonnxruntime_providers_vitisai.so "$capi/"
      fi
    '';

    passthru = (oldAttrs.passthru or { }) // {
      inherit onnxruntime-vitisai;
      category = "AMD NPU";
      library = true;
    };

    meta = oldAttrs.meta // {
      description = "ONNX Runtime Python bindings with the VitisAI execution provider";
      longDescription = ''
        A drop-in build of the `onnxruntime` Python package: it provides the
        `onnxruntime` import, so it conflicts with
        `python3Packages.onnxruntime` and the two cannot share one Python
        environment.
      '';
      sourceProvenance = [ lib.sourceTypes.fromSource ];
      maintainers = with lib.maintainers; [ jylhis ];
      platforms = [ "x86_64-linux" ];
    };
  })
