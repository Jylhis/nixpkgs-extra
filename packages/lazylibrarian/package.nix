# LazyLibrarian: follows authors and fetches their ebooks, audiobooks, comics
# and magazines, with a web UI.
#
# Upstream is a source tree run as `python LazyLibrarian.py`, so it is copied
# to share/lazylibrarian and wrapped. version.py is "package" (upstream's
# switch for distro installs) and an empty unbundled.libs disables the
# unbundler, which would pip install under the store path. The wrapper
# defaults --datadir to the XDG data dir; a later --datadir overrides it.
#
# Upstream has no tags; the version is the one in pyproject.toml.
{
  lib,
  stdenvNoCC,
  fetchFromGitLab,
  fetchPypi,
  python3,
  makeWrapper,
  nix-update-script,
}:

let
  py = python3.pkgs;

  # Soulseek downloads (lazylibrarian/soulseek.py); not in nixpkgs.
  slskd-api = py.buildPythonPackage (finalAttrs: {
    pname = "slskd-api";
    version = "0.2.4";
    pyproject = true;

    # The sdist, not the GitHub tag: setuptools-git-versioning needs .git
    # to find the version.
    src = fetchPypi {
      pname = "slskd_api";
      inherit (finalAttrs) version;
      hash = "sha256-7jOSBGu5n4L05GLwQgtPEdwT2ai1hpZBu3h9IaLd09E=";
    };

    build-system = [
      py.setuptools
      py.setuptools-git-versioning
    ];
    dependencies = [ py.requests ];
    pythonImportsCheck = [ "slskd_api" ];
  });

  dependencies =
    ps: with ps; [
      apprise
      apscheduler
      beautifulsoup4
      cherrypy
      cherrypy-cors
      curl-cffi
      deluge-client
      googletrans
      html5lib
      httpagentparser
      httplib2
      irc
      iso639-lang
      langid
      lxml
      mako
      pillow
      pyopenssl
      pyparsing
      pypdf
      python-magic
      rapidfuzz
      requests
      slskd-api
      tzdata
      urllib3
      webencodings
      xmltodict
    ];

  pythonEnv = python3.withPackages dependencies;

  # Upstream's unit tests run from the source tree (pytest's pythonpath = ".").
  testEnv = python3.withPackages (
    ps:
    dependencies ps
    ++ (with ps; [
      mock
      pytest
      pytest-order
    ])
  );
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "lazylibrarian";
  version = "2026.09.19";

  src = fetchFromGitLab {
    owner = "LazyLibrarian";
    repo = "LazyLibrarian";
    rev = "2a5627519f660c0db535b400d6a9c7b6c483b4d3";
    hash = "sha256-jT7mTsW5Qk5o6eNUJtWKP9qXh1znDxVfTTbc3lGEzmo=";
  };

  nativeBuildInputs = [ makeWrapper ];

  postPatch = ''
    substituteInPlace lazylibrarian/version.py \
      --replace-fail 'LAZYLIBRARIAN_VERSION = "master"' 'LAZYLIBRARIAN_VERSION = "package"'
    echo '[]' > unbundled.libs
  '';

  dontBuild = true;

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    # Both need network: test_icrawler crawls live image search engines (and
    # hangs without it), the deselected test looks an author up unmocked.
    HOME=$(mktemp -d) ${testEnv.interpreter} -m pytest -p no:cacheprovider unittests \
      --ignore=unittests/test_icrawler.py \
      --deselect=unittests/test_importer.py::ImporterTest::test_add_author_name_to_db_UnknownPerson
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/lazylibrarian
    cp -r LazyLibrarian.py lazylibrarian lib data unbundled.libs \
      example.* example_* $out/share/lazylibrarian/

    makeWrapper ${pythonEnv.interpreter} $out/bin/lazylibrarian \
      --add-flags "$out/share/lazylibrarian/LazyLibrarian.py" \
      --add-flags '--datadir="''${XDG_DATA_HOME:-$HOME/.local/share}/lazylibrarian"'

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    export HOME=$(mktemp -d)
    $out/bin/lazylibrarian --help > /dev/null
    runHook postInstallCheck
  '';

  passthru = {
    category = "Media";
    inherit pythonEnv;
    updateScript = nix-update-script { extraArgs = [ "--version=branch" ]; };
  };

  meta = {
    description = "Follows authors and downloads their ebooks, audiobooks and magazines";
    homepage = "https://lazylibrarian.gitlab.io/";
    license = lib.licenses.gpl3Only;
    sourceProvenance = [ lib.sourceTypes.fromSource ];
    maintainers = with lib.maintainers; [ jylhis ];
    mainProgram = "lazylibrarian";
    platforms = lib.platforms.linux;
  };
})
