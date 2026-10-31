// lint-commits checks the commits in <base>..HEAD against the nixpkgs commit
// rules its CI enforces (ci/github-script/lint-commits.ts), plus two
// repo-specific ones:
//
//   - error: the subject has no ": ", ends in ".", starts with fixup!,
//     squash! or amend!, or looks like a Conventional Commit;
//   - error: author or committer name is empty or email is not an address;
//   - error: an Assisted-by: trailer is not "AGENT:MODEL [tools...]";
//   - warning: the subject prefix names no known package, module or repo area.
//
// Usage: lint-commits [-known FILE] <base>
package main

import (
	"bufio"
	"bytes"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"regexp"
	"slices"
	"strings"
)

// Commit is one commit as read from git log.
type Commit struct {
	SHA            string
	Subject        string
	Body           string
	AuthorName     string
	AuthorEmail    string
	CommitterName  string
	CommitterEmail string
	// Every path segment of every file the commit touches.
	PathSegments []string
}

// Result holds what lint found for one commit.
type Result struct {
	Errors   []string
	Warnings []string
}

// From nixpkgs ci/github-script/lint-commits.ts.
var conventionalTypes = []string{
	"build", "chore", "ci", "doc", "docs", "feat", "feature", "fix",
	"perf", "refactor", "services", "style", "test", "update",
}

// Subject prefixes that name a part of the repo rather than a package or
// module. "area/anything" is accepted for these too.
var repoAreas = []string{
	"AGENTS.md", "README", "README.md", "THIRD-PARTY-NOTICES.md",
	"checks", "ci", "docs", "flake", "flake.lock", "flake.nix", "github",
	"lib", "llm-agents-overrides", "maintainers", "modules", "nixpkgs-extra",
	"overlays", "overrides", "packages", "rules", "scripts", "treefmt",
	"treewide",
}

var (
	assistedByLine = regexp.MustCompile(`(?m)^Assisted-by:.*$`)
	// AGENT:MODEL, then optional space-separated tools. AGENT may contain
	// spaces ("Claude Code"); MODEL may not.
	assistedByFormat = regexp.MustCompile(`^Assisted-by: [^\s:][^:]*:\S+( \S+)*$`)
	emailFormat      = regexp.MustCompile(`^.+@.*$`)
)

func conventionalRegex(segments []string) *regexp.Regexp {
	// A type that is also a path segment the commit touches ("docs: ..." for
	// a change under docs/) is a component name, not a Conventional Commit.
	types := slices.DeleteFunc(slices.Clone(conventionalTypes), func(t string) bool {
		return slices.Contains(segments, t)
	})
	return regexp.MustCompile(`^(` + strings.Join(types, "|") + `)!?(\(.*\))?!?:`)
}

// knownPrefix reports whether one comma-separated part of a subject prefix
// names something in the repo.
func knownPrefix(part string, known map[string]bool) bool {
	if known[part] || slices.Contains(repoAreas, part) {
		return true
	}
	// A member of a known set: haxePackages.hxcpp, llm-agents.<attr> is
	// listed in full by the caller.
	if head, _, ok := strings.Cut(part, "."); ok && known[head] {
		return true
	}
	if head, _, ok := strings.Cut(part, "/"); ok && slices.Contains(repoAreas, head) {
		return true
	}
	return false
}

func lint(c Commit, known map[string]bool) Result {
	var r Result
	errorf := func(format string, a ...any) { r.Errors = append(r.Errors, fmt.Sprintf(format, a...)) }

	prefix, _, hasColon := strings.Cut(c.Subject, ": ")
	if !hasColon {
		errorf(`subject has no ": " after the component`)
	}
	if strings.HasSuffix(c.Subject, ".") {
		errorf("subject ends in a period")
	}
	for _, f := range []string{"amend!", "fixup!", "squash!"} {
		if strings.HasPrefix(c.Subject, f) {
			errorf("subject starts with %s; run git rebase --autosquash", f)
		}
	}
	if conventionalRegex(c.PathSegments).MatchString(c.Subject) {
		errorf("subject uses Conventional Commits; name the package, module or area instead")
	}

	if c.AuthorName == "" {
		errorf("author name is empty")
	}
	if !emailFormat.MatchString(c.AuthorEmail) {
		errorf("author email %q is not an address", c.AuthorEmail)
	}
	if c.CommitterName == "" {
		errorf("committer name is empty")
	}
	if !emailFormat.MatchString(c.CommitterEmail) {
		errorf("committer email %q is not an address", c.CommitterEmail)
	}

	for _, line := range assistedByLine.FindAllString(c.Body, -1) {
		if !assistedByFormat.MatchString(line) {
			errorf("%q is not \"Assisted-by: AGENT:MODEL [tools...]\"", line)
		}
	}

	if hasColon {
		for part := range strings.SplitSeq(prefix, ",") {
			part = strings.TrimSpace(part)
			if !knownPrefix(part, known) {
				r.Warnings = append(r.Warnings,
					fmt.Sprintf("%q is not a known package, module or repo area", part))
			}
		}
	}
	return r
}

// Field and record separators for git log --format.
const (
	fieldSep  = "\x1f"
	recordSep = "\x1e"
)

func parseLog(out string) []Commit {
	var commits []Commit
	for rec := range strings.SplitSeq(out, recordSep) {
		rec = strings.TrimLeft(rec, "\n")
		if rec == "" {
			continue
		}
		f := strings.SplitN(rec, fieldSep, 6)
		if len(f) < 6 {
			continue
		}
		subject, body, _ := strings.Cut(strings.TrimRight(f[5], "\n"), "\n")
		commits = append(commits, Commit{
			SHA:            f[0],
			AuthorName:     f[1],
			AuthorEmail:    f[2],
			CommitterName:  f[3],
			CommitterEmail: f[4],
			Subject:        subject,
			Body:           strings.TrimSpace(body),
		})
	}
	return commits
}

func git(args ...string) (string, error) {
	var stderr bytes.Buffer
	cmd := exec.Command("git", args...)
	cmd.Stderr = &stderr
	out, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("git %s: %w: %s", strings.Join(args, " "), err, stderr.String())
	}
	return string(out), nil
}

func readKnown(path string) (map[string]bool, error) {
	known := map[string]bool{}
	if path == "" {
		return known, nil
	}
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	s := bufio.NewScanner(f)
	for s.Scan() {
		if line := strings.TrimSpace(s.Text()); line != "" {
			known[line] = true
		}
	}
	return known, s.Err()
}

func run() (failed bool, err error) {
	knownFile := flag.String("known", "", "file listing known subject prefixes, one per line")
	flag.Usage = func() {
		fmt.Fprintln(flag.CommandLine.Output(), "usage: lint-commits [-known FILE] <base>")
		flag.PrintDefaults()
	}
	flag.Parse()
	if flag.NArg() != 1 {
		flag.Usage()
		os.Exit(2)
	}
	known, err := readKnown(*knownFile)
	if err != nil {
		return false, err
	}

	format := strings.Join([]string{"%H", "%an", "%ae", "%cn", "%ce", "%B"}, fieldSep) + recordSep
	out, err := git("log", "--no-merges", "--format="+format, flag.Arg(0)+"..HEAD")
	if err != nil {
		return false, err
	}
	commits := parseLog(out)
	for i, c := range commits {
		paths, err := git("diff-tree", "--root", "--no-commit-id", "--name-only", "-r", c.SHA)
		if err != nil {
			return false, err
		}
		for p := range strings.FieldsSeq(paths) {
			commits[i].PathSegments = append(commits[i].PathSegments, strings.Split(p, "/")...)
		}
	}

	for _, c := range commits {
		r := lint(c, known)
		for _, e := range r.Errors {
			fmt.Printf("error: %.12s %s: %s\n", c.SHA, c.Subject, e)
		}
		for _, w := range r.Warnings {
			fmt.Printf("warning: %.12s %s: %s\n", c.SHA, c.Subject, w)
		}
		failed = failed || len(r.Errors) > 0
	}
	fmt.Printf("checked %d commits\n", len(commits))
	return failed, nil
}

func main() {
	failed, err := run()
	if err != nil {
		fmt.Fprintln(os.Stderr, "lint-commits:", err)
		os.Exit(2)
	}
	if failed {
		os.Exit(1)
	}
}
