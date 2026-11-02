// nur-eval runs NUR's evaluation check (ci/nur/eval.py in nix-community/NUR)
// on this repo's nur.nix, then fails if nix-env listed fewer packages than
// nur.nix exports. NUR keeps the last revision that passed and drops packages
// it can't see without telling anyone, so both failures matter.
//
// Usage: nur-eval -eval FILE -nixpkgs PATH [-repo DIR]
package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"time"
)

// NUR's own limit for one repository.
const evalTimeout = 180 * time.Second

func main() {
	evalFile := flag.String("eval", "", "eval-repo.nix, the NUR evalRepo stand-in")
	nixpkgs := flag.String("nixpkgs", "", "nixpkgs to evaluate against")
	repo := flag.String("repo", ".", "repository root holding nur.nix")
	flag.Parse()
	if *evalFile == "" || *nixpkgs == "" || flag.NArg() != 0 {
		flag.Usage()
		os.Exit(2)
	}
	if err := run(*evalFile, *nixpkgs, *repo); err != nil {
		fmt.Fprintln(os.Stderr, "nur-eval:", err)
		os.Exit(1)
	}
}

func run(evalFile, nixpkgs, repo string) error {
	repo, err := filepath.Abs(repo)
	if err != nil {
		return err
	}

	expected, err := exportedNames(evalFile, nixpkgs, repo)
	if err != nil {
		return err
	}
	listed, err := nurListed(evalFile, nixpkgs, repo)
	if err != nil {
		return err
	}

	fmt.Printf("nix-env listed %d of %d packages\n", len(listed), len(expected))
	if gone := missing(expected, listed); len(gone) > 0 {
		return fmt.Errorf("NUR would not list: %v", gone)
	}
	return nil
}

// exportedNames evaluates nur.nix without restrictions and returns its
// top-level derivation names.
func exportedNames(evalFile, nixpkgs, repo string) ([]string, error) {
	out, err := nix(context.Background(), nil, "nix-instantiate",
		"--eval", "--strict", "--json", evalFile,
		"-I", "nixpkgs="+nixpkgs,
		"--arg", "repo", repo,
		"--arg", "namesOnly", "true",
	)
	if err != nil {
		return nil, err
	}
	var names []string
	if err := json.Unmarshal(out, &names); err != nil {
		return nil, fmt.Errorf("parse nur.nix names: %w", err)
	}
	return names, nil
}

// nurListed runs NUR's nix-env command and returns the attribute names it
// lists. Flags and environment follow eval.py.
func nurListed(evalFile, nixpkgs, repo string) ([]string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), evalTimeout)
	defer cancel()
	out, err := nix(ctx, []string{"NIXPKGS_ALLOW_UNSUPPORTED_SYSTEM=1"}, "nix-env",
		"-f", evalFile,
		"-qa", "*",
		"--meta",
		"--json",
		"--allowed-uris", "https://static.rust-lang.org",
		"--option", "restrict-eval", "true",
		"--option", "allow-import-from-derivation", "true",
		"--drv-path",
		"--show-trace",
		"-I", "nixpkgs="+nixpkgs,
		"-I", repo,
		"-I", evalFile,
		"--arg", "repo", repo,
	)
	if errors.Is(ctx.Err(), context.DeadlineExceeded) {
		return nil, fmt.Errorf("evaluation took longer than NUR's %s", evalTimeout)
	}
	if err != nil {
		return nil, err
	}
	var listed map[string]json.RawMessage
	if err := json.Unmarshal(out, &listed); err != nil {
		return nil, fmt.Errorf("parse nix-env output: %w", err)
	}
	names := make([]string, 0, len(listed))
	for name := range listed {
		names = append(names, name)
	}
	slices.Sort(names)
	return names, nil
}

// nix runs a Nix command and returns its stdout; stderr goes to ours.
func nix(ctx context.Context, env []string, name string, args ...string) ([]byte, error) {
	cmd := exec.CommandContext(ctx, name, args...)
	cmd.Env = append(os.Environ(), env...)
	cmd.Stderr = os.Stderr
	var stdout bytes.Buffer
	cmd.Stdout = &stdout
	if err := cmd.Run(); err != nil {
		return nil, fmt.Errorf("%s: %w", name, err)
	}
	return stdout.Bytes(), nil
}

// missing returns the names in expected that are not in listed, sorted.
func missing(expected, listed []string) []string {
	var gone []string
	for _, name := range expected {
		if !slices.Contains(listed, name) {
			gone = append(gone, name)
		}
	}
	slices.Sort(gone)
	return gone
}
