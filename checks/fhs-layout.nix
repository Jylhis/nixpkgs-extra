# A package's pkgs-<name> check: it must build, and only FHS-like
# directories may sit directly under $out; anything else collides in buildEnv
# and Home Manager profiles. Adapted from numtide/llm-agents.nix (MIT),
# rev 20f2a05, lib/check-package.nix.
{ pkgs }:
name: pkg:
pkgs.runCommand "check-${name}" { } ''
  for f in ${pkg}/* ${pkg}/.[!.]*; do
    case "$(basename "$f")" in
      bin|sbin|lib|lib64|libexec|share|include|etc|opt|nix-support|'*'|'.[!.]*') ;;
      *) echo "${name}: $f is not FHS-like (see AGENTS.md, Output layout)"; exit 1 ;;
    esac
  done
  ln -s ${pkg} $out
''
