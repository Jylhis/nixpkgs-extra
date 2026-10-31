# libwebsockets 4.5.8, for lemonade-server; not exported because it overrides a
# nixpkgs attribute.
#
# Lemonade's /realtime WebSocket needs 4.5.8: 4.4.1 emits a malformed HTTP/101
# upgrade response (missing the final CRLF) that strict clients reject with
# 1006. 4.5.8 has the CVE-2025-11677 fix; the nixpkgs back-port patch no
# longer applies, so patches are dropped.
{
  libwebsockets,
  fetchFromGitHub,
}:
libwebsockets.overrideAttrs (
  finalAttrs: old: {
    version = "4.5.8";
    src = fetchFromGitHub {
      owner = "warmcat";
      repo = "libwebsockets";
      tag = "v${finalAttrs.version}";
      hash = "sha256-0pLBxOSKaxboHd9L27RKKqSJ9lVH4wPgKSyXEoJMal4=";
    };
    patches = [ ];
    postInstall = (old.postInstall or "") + ''
      for pc in "$out"/lib/pkgconfig/*.pc "$dev"/lib/pkgconfig/*.pc; do
        [ -f "$pc" ] || continue
        sed -i \
          -e "s|^libdir=.*$|libdir=$out/lib|" \
          -e "s|^includedir=.*$|includedir=$dev/include|" \
          "$pc"
      done
    '';
  }
)
