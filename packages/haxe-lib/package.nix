# Haxelib packaging helpers. installLibHaxe and buildHaxeLib are adapted from
# NixOS/nixpkgs (MIT), rev 31ecbaca, pkgs/top-level/haxe-packages.nix, so the
# packages here can move into that file unchanged. Two extensions:
#
#  - buildHaxeLib accepts `src`: a source-built library (fetchFromGitHub plus a
#    buildPhase) installs from the build tree instead of a lib.haxe.org zip.
#  - mkHaxelibRepo merges several libraries into one haxelib repository, the
#    single-directory HAXELIB_PATH that haxelib itself expects.
{
  lib,
  stdenv,
  fetchzip,
  buildEnv,
  haxe,
  neko,
}:
let
  withCommas = lib.replaceStrings [ "." ] [ "," ];

  # Haxelib repository layout: <repo>/<lib>/<ver,with,commas>/ plus a
  # <repo>/<lib>/.current naming the selected version.
  installLibHaxe =
    {
      libname,
      version,
      files ? "*",
    }:
    ''
      mkdir -p "$out/lib/haxe/${withCommas libname}/${withCommas version}"
      echo -n "${version}" > $out/lib/haxe/${withCommas libname}/.current
      cp -dpR ${files} "$out/lib/haxe/${withCommas libname}/${withCommas version}/"
    '';

  buildHaxeLib =
    {
      libname,
      version,
      sha256 ? null,
      ...
    }@attrs:
    stdenv.mkDerivation (
      removeAttrs attrs [
        "libname"
        "sha256"
        "files"
      ]
      // {
        pname = libname;
        inherit version;

        buildInputs = (attrs.buildInputs or [ ]) ++ [
          haxe
          neko
        ]; # for setup-hook.sh to work
        src =
          attrs.src or (fetchzip rec {
            name = "${libname}-${version}";
            url = "http://lib.haxe.org/files/3.0/${withCommas name}.zip";
            inherit sha256;
            stripRoot = false;
          });

        installPhase =
          attrs.installPhase or (
            if attrs ? src then
              ''
                runHook preInstall
                ${installLibHaxe {
                  inherit libname version;
                  files = attrs.files or "*";
                }}
                runHook postInstall
              ''
            else
              ''
                runHook preInstall
                (
                  if [ $(ls $src | wc -l) == 1 ]; then
                    cd $src/* || cd $src
                  else
                    cd $src
                  fi
                  ${installLibHaxe { inherit libname version; }}
                )
                runHook postInstall
              ''
          );

        meta = {
          homepage = "https://lib.haxe.org/p/${libname}";
          license = lib.licenses.bsd2;
          platforms = lib.platforms.all;
          description = throw "please write meta.description";
        }
        // attrs.meta;
      }
    );

  # One haxelib repository holding every library in `libraries`; point
  # HAXELIB_PATH at "${repo}/lib/haxe". Library dirs are distinct names, so the
  # merge never collides unless two versions of one library are requested.
  mkHaxelibRepo =
    {
      name ? "haxelib-repo",
      libraries,
    }:
    buildEnv {
      inherit name;
      paths = libraries;
      pathsToLink = [ "/lib/haxe" ];
    };
in
{
  inherit
    withCommas
    installLibHaxe
    buildHaxeLib
    mkHaxelibRepo
    ;
}
