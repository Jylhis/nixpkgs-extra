# grafanaPlugins with marcusolsson-treemap-panel, missing next to its marcusolsson siblings.
{ final, prev }:
let
  inherit (final) lib;
  pname = "marcusolsson-treemap-panel";
  version = "2.1.1";
in
prev.grafanaPlugins
// {
  ${pname} = prev.grafanaPlugins.grafanaPlugin {
    inherit pname version;
    packages.any = {
      url = "https://grafana.com/api/plugins/${pname}/versions/${version}/download";
      hash = "sha256-7aNskgqnzpjlKr51J0uhd01ukVc4L5Jb9gxBtYzsflU=";
    };

    meta = {
      description = "Grafana panel plugin that shows hierarchical data as a treemap";
      license = lib.licenses.asl20;
      maintainers = with lib.maintainers; [ jylhis ];
    };
  };
}
