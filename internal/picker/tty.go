package picker

import (
	"io"
	"os"
)

// openTTY 优先用 /dev/tty 作为输入，避免被 $() 捕获 stdout 时输入端拿不到键盘。
func openTTY() io.Reader {
	f, err := os.Open("/dev/tty")
	if err != nil {
		return os.Stdin
	}
	return f
}

// ttyOut 优先把 UI 输出到 /dev/tty，避免被 $() 捕获 stdout。
func ttyOut() io.Writer {
	f, err := os.OpenFile("/dev/tty", os.O_WRONLY, 0)
	if err != nil {
		return os.Stderr
	}
	return f
}
