package config

import (
	"os"
	"path/filepath"
)

func Home() string {
	h, err := os.UserHomeDir()
	if err != nil {
		return ""
	}
	return h
}

func ZshHistoryPath() string { return filepath.Join(Home(), ".zsh_history") }
func CXDir() string          { return filepath.Join(Home(), ".cx") }
func DBPath() string         { return filepath.Join(CXDir(), "cx.db") }

func EnsureDirs() error {
	return os.MkdirAll(CXDir(), 0o755)
}
