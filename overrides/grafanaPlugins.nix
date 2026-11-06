# grafanaPlugins with marcusolsson-treemap-panel, missing next to its marcusolsson siblings.
{ final, prev }:
let
  inherit (final) lib;
in
prev.grafanaPlugins
// {
  marcusolsson-treemap-panel = prev.grafanaPlugins.grafanaPlugin {
    pname = "marcusolsson-treemap-panel";
    version = "2.1.1";
    packages.any = {
      url = "https://grafana.com/api/plugins/marcusolsson-treemap-panel/versions/2.1.1/download";
      hash = "sha256-7aNskgqnzpjlKr51J0uhd01ukVc4L5Jb9gxBtYzsflU=";
    };

    meta = {
      description = "Grafana panel plugin that shows hierarchical data as a treemap";
      homepage = "https://grafana.com/grafana/plugins/marcusolsson-treemap-panel";
      license = lib.licenses.asl20;
      maintainers = with lib.maintainers; [ jylhis ];
      platforms = lib.platforms.unix;
    };
  };
}
