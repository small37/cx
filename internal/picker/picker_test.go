package picker

import "testing"

func TestMatch(t *testing.T) {
	cases := []struct {
		name    string
		command string
		query   string
		want    bool
	}{
		{name: "empty query", command: "git status", query: "", want: true},
		{name: "case insensitive", command: "Git Status", query: "git", want: true},
		{name: "and terms", command: "git commit --amend", query: "git amend", want: true},
		{name: "missing term", command: "git status", query: "git push", want: false},
		{name: "trim query", command: "docker compose up", query: "  compose   up  ", want: true},
	}

	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if got := Match(c.command, c.query); got != c.want {
				t.Fatalf("Match(%q, %q)=%v, want %v", c.command, c.query, got, c.want)
			}
		})
	}
}
