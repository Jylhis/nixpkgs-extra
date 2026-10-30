# librepo with HTML API docs (doc output), separate debug info and FindLibrepo.cmake.
#
# separateDebugInfo already adds -ggdb, so the build type stays nixpkgs'
# Release. The Python module moves to $py in postInstall instead of nixpkgs'
# postFixup: debug info is split during fixup, and its .build-id links must
# point at the module's final place. The Python docs import the freshly
# built module through the PYTHONPATH the upstream `doc` target sets.
{ final, prev }:
prev.librepo.overrideAttrs (old: {
  outputs = old.outputs ++ [ "doc" ];

  nativeBuildInputs = old.nativeBuildInputs ++ [ final.python3Packages.sphinx ];

  separateDebugInfo = true;

  postBuild = (old.postBuild or "") + ''
    make doc
    mkdir -p "$doc/share/doc/librepo/html"
    cp -r doc/c/html "$doc/share/doc/librepo/html/c"
    cp -r doc/python "$doc/share/doc/librepo/html/python"
    rm -r "$doc"/share/doc/librepo/html/python/{CMakeFiles,Makefile,*.cmake}
  '';

  postInstall = (old.postInstall or "") + ''
    moveToOutput "lib/${final.python3.libPrefix}" "$py"
  '';

  postFixup = ''
    install -Dm644 "$src/utils/FindLibrepo.cmake" "$dev/share/cmake/librepo/FindLibrepo.cmake"
  '';
})
