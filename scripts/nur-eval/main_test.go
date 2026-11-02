package main

import (
	"slices"
	"testing"
)

func TestMissing(t *testing.T) {
	tests := []struct {
		name             string
		expected, listed []string
		want             []string
	}{
		{"all listed", []string{"a", "b"}, []string{"b", "a"}, nil},
		{"none listed", []string{"b", "a"}, nil, []string{"a", "b"}},
		{"extra listed", []string{"a"}, []string{"a", "z"}, nil},
		{"one dropped", []string{"a", "b", "c"}, []string{"a", "c"}, []string{"b"}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := missing(tt.expected, tt.listed); !slices.Equal(got, tt.want) {
				t.Errorf("missing(%v, %v) = %v, want %v", tt.expected, tt.listed, got, tt.want)
			}
		})
	}
}
