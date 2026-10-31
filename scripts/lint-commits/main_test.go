package main

import (
	"slices"
	"strings"
	"testing"
)

func TestLint(t *testing.T) {
	known := map[string]bool{
		"oryx":                       true,
		"nixos/langfuse":             true,
		"home-manager/phoenix":       true,
		"haxePackages":               true,
		"llm-agents.agentsview":      true,
		"python-onnxruntime-vitisai": true,
	}
	tests := []struct {
		name     string
		subject  string
		body     string
		segments []string
		errors   []string // substrings, in order
		warnings []string
	}{
		{name: "version bump", subject: "oryx: 0.8.0 -> 0.9.0"},
		{name: "module init", subject: "nixos/langfuse: init"},
		{name: "home module", subject: "home-manager/phoenix: add port option"},
		{name: "set member", subject: "haxePackages.hxcpp: 4.3.171"},
		{name: "llm-agents override", subject: "llm-agents.agentsview: enable feature"},
		{name: "repo area", subject: "checks: add parse"},
		{name: "repo area path", subject: "scripts/lint-commits: init"},
		{name: "several components", subject: "oryx, nixos/langfuse: fix typo"},
		{
			name:    "no colon",
			subject: "update oryx",
			errors:  []string{`no ": "`},
		},
		{
			name:    "colon without space",
			subject: "oryx:0.9.0",
			errors:  []string{`no ": "`},
		},
		{
			name:    "trailing period",
			subject: "oryx: 0.8.0 -> 0.9.0.",
			errors:  []string{"period"},
		},
		{
			name:     "fixup",
			subject:  "fixup! oryx: 0.9.0",
			errors:   []string{"fixup!"},
			warnings: []string{"fixup! oryx"},
		},
		{
			name:     "conventional commit",
			subject:  "feat(oryx): add flag",
			errors:   []string{"Conventional"},
			warnings: []string{"feat(oryx)"},
		},
		{
			name:    "conventional breaking",
			subject: "fix!: oryx crash",
			errors:  []string{"Conventional"},
			// "fix!" is not a component either.
			warnings: []string{"fix!"},
		},
		{
			name:     "docs commit touching TODO only",
			subject:  "docs: add upstreaming TODO",
			segments: []string{"TODO.md"},
			errors:   []string{"Conventional"},
		},
		{
			name:     "docs commit touching docs/",
			subject:  "docs: add upstreaming guide",
			segments: []string{"docs", "upstreaming.md"},
		},
		{
			name:     "unknown component",
			subject:  "frobnicate: 1.0 -> 2.0",
			warnings: []string{"frobnicate"},
		},
		{
			name:     "unknown module",
			subject:  "nixos/nope: init",
			warnings: []string{"nixos/nope"},
		},
		{
			name:    "assisted-by ok",
			subject: "oryx: 0.9.0",
			body:    "Why.\n\nAssisted-by: Claude Code:claude-opus-5-5 nix shellcheck",
		},
		{
			name:    "assisted-by without tools",
			subject: "oryx: 0.9.0",
			body:    "Assisted-by: Claude Code:claude-opus-5-5",
		},
		{
			name:    "assisted-by without model",
			subject: "oryx: 0.9.0",
			body:    "Assisted-by: Claude Code",
			errors:  []string{"AGENT:MODEL"},
		},
		{
			name:    "assisted-by empty agent",
			subject: "oryx: 0.9.0",
			body:    "Assisted-by: :claude-opus-5-5",
			errors:  []string{"AGENT:MODEL"},
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			c := Commit{
				SHA:            "0123456789abcdef",
				Subject:        tt.subject,
				Body:           tt.body,
				AuthorName:     "A",
				AuthorEmail:    "a@example.com",
				CommitterName:  "A",
				CommitterEmail: "a@example.com",
				PathSegments:   tt.segments,
			}
			r := lint(c, known)
			check(t, "errors", r.Errors, tt.errors)
			check(t, "warnings", r.Warnings, tt.warnings)
		})
	}
}

func TestLintMetadata(t *testing.T) {
	c := Commit{Subject: "oryx: 0.9.0", AuthorEmail: "nope", CommitterName: "C", CommitterEmail: "c@x"}
	r := lint(c, map[string]bool{"oryx": true})
	check(t, "errors", r.Errors, []string{"author name", "author email"})
}

func check(t *testing.T, what string, got, want []string) {
	t.Helper()
	if len(got) != len(want) {
		t.Fatalf("%s: got %q, want %d matching %q", what, got, len(want), want)
	}
	for i := range want {
		if !strings.Contains(got[i], want[i]) {
			t.Errorf("%s[%d]: %q does not contain %q", what, i, got[i], want[i])
		}
	}
}

func TestParseLog(t *testing.T) {
	rec := func(fields ...string) string { return strings.Join(fields, fieldSep) + recordSep }
	out := rec("aaa", "A", "a@x", "C", "c@x", "oryx: 0.9.0\n\nBody line.\n\nAssisted-by: X:y\n") +
		"\n" + rec("bbb", "B", "b@x", "C", "c@x", "checks: add parse\n")
	got := parseLog(out)
	if len(got) != 2 {
		t.Fatalf("got %d commits, want 2", len(got))
	}
	if got[0].Subject != "oryx: 0.9.0" || got[0].Body != "Body line.\n\nAssisted-by: X:y" {
		t.Errorf("first commit: %+v", got[0])
	}
	if got[1].SHA != "bbb" || got[1].Subject != "checks: add parse" || got[1].Body != "" {
		t.Errorf("second commit: %+v", got[1])
	}
	if !slices.Equal([]string{got[0].AuthorName, got[0].CommitterEmail}, []string{"A", "c@x"}) {
		t.Errorf("fields: %+v", got[0])
	}
}
