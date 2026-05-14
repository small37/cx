package history

import (
	"os"
	"path/filepath"
	"testing"
)

func TestParseEntry(t *testing.T) {
	cases := []struct {
		in     string
		wantTs int64
		wantCm string
	}{
		{": 1715000000:0;git status", 1715000000, "git status"},
		{"git status", 0, "git status"},
		{"    26  _dao_deploy.ps1", 0, "_dao_deploy.ps1"},
		{": 1715000010:5;    9  ls -la", 1715000010, "ls -la"},
		{"", 0, ""},
	}
	for _, c := range cases {
		ts, cmd := parseEntry(c.in)
		if ts != c.wantTs || cmd != c.wantCm {
			t.Errorf("parseEntry(%q)=(%d,%q), want (%d,%q)", c.in, ts, cmd, c.wantTs, c.wantCm)
		}
	}
}

func TestUnmetafyChinese(t *testing.T) {
	// "中" UTF-8 = E4 B8 AD. Metafied: 0x83 (0xE4^0x20=0xC4), 0x83 (0xB8^0x20=0x98), 0x83 (0xAD^0x20=0x8D)
	src := []byte{0x83, 0xC4, 0x83, 0x98, 0x83, 0x8D}
	got := unmetafy(src)
	want := []byte{0xE4, 0xB8, 0xAD}
	if string(got) != string(want) {
		t.Errorf("unmetafy=%x, want %x", got, want)
	}
}

func TestLoadFromSortAndDedup(t *testing.T) {
	dir := t.TempDir()
	p := filepath.Join(dir, "h")
	content := ": 100:0;a\n" +
		": 200:0;b\n" +
		": 300:0;a\n" + // a 更新到 ts=300
		": 150:0;c\n"
	if err := os.WriteFile(p, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
	got, err := LoadFrom(p, 10)
	if err != nil {
		t.Fatal(err)
	}
	want := []string{"a", "b", "c"}
	if len(got) != len(want) {
		t.Fatalf("len=%d want=%d (%v)", len(got), len(want), got)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Errorf("[%d]=%q want %q", i, got[i], want[i])
		}
	}
}
