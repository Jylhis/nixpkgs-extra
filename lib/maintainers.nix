# Repo maintainers in nixpkgs' maintainers/maintainer-list.nix format. The
# overlay merges this into lib.maintainers, so package meta reads
# `maintainers = with lib.maintainers; [ jylhis ];` exactly as upstream would.
{
  jylhis = {
    name = "Markus Jylhänkangas";
    email = "markus@jylhis.com";
    github = "Jylhis";
    githubId = 2924267;
  };
}
