/* Setgid front end for "nix-ccache --show-stats" and friends, replacing
 * nixpkgs' Perl wrapper: security.wrappers only accepts ELF targets. It runs
 * ccache with an environment holding only CCACHE_DIR, and with no argument
 * besides the stats, clear and version flags. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static const char *untaint(const char *arg) {
  if (!strcmp(arg, "-C") || !strcmp(arg, "--clear"))
    return "-C";
  if (!strcmp(arg, "-V") || !strcmp(arg, "--version"))
    return "-V";
  if (!strcmp(arg, "-s") || !strcmp(arg, "--show-stats"))
    return "-s";
  if (!strcmp(arg, "-z") || !strcmp(arg, "--zero-stats"))
    return "-z";
  return NULL;
}

int main(int argc, char **argv) {
  char *envp[] = {"CCACHE_DIR=" CACHE_DIR, NULL};
  char *help[] = {CCACHE, "-h", NULL};
  char **args = calloc(argc + 1, sizeof(char *));

  if (!args)
    return 1;
  args[0] = CCACHE;
  for (int i = 1; i < argc; i++) {
    const char *flag = untaint(argv[i]);
    if (!flag) {
      execve(CCACHE, help, envp);
      perror(CCACHE);
      return 1;
    }
    args[i] = (char *)flag;
  }
  execve(CCACHE, args, envp);
  perror(CCACHE);
  return 1;
}
