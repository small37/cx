package history

import (
	"os"
	"regexp"
	"sort"
	"strconv"
	"strings"

	"github.com/one/cx/internal/config"
)

// `history` / `fc -l` 输出前缀：开头空白 + 数字 + 空白
var histListPrefix = regexp.MustCompile(`^\s*\d+\s+`)

// zsh metafy: bytes >= 0x80 stored as (0x83, byte ^ 0x20). Reverse it.
func unmetafy(data []byte) []byte {
	out := make([]byte, 0, len(data))
	for i := 0; i < len(data); i++ {
		if data[i] == 0x83 && i+1 < len(data) {
			out = append(out, data[i+1]^0x20)
			i++
		} else {
			out = append(out, data[i])
		}
	}
	return out
}

type entry struct {
	order int
	ts    int64
	cmd   string
}

// 解析单条（已合并续行后的）历史记录。
func parseEntry(raw string) (int64, string) {
	s := strings.TrimRight(raw, "\n")
	s = strings.TrimRight(s, "\r")
	if s == "" {
		return 0, ""
	}
	var ts int64
	if strings.HasPrefix(s, ":") {
		// ": <ts>:<dur>;<cmd>"
		if idx := strings.Index(s, ";"); idx != -1 {
			head := s[1:idx]
			parts := strings.Split(head, ":")
			if len(parts) > 0 {
				if v, err := strconv.ParseInt(strings.TrimSpace(parts[0]), 10, 64); err == nil {
					ts = v
				}
			}
			s = s[idx+1:]
		}
	}
	s = strings.TrimSpace(s)
	if m := histListPrefix.FindStringIndex(s); m != nil {
		s = s[m[1]:]
	}
	return ts, strings.TrimSpace(s)
}

// Load 读取 zsh 历史文件，按时间戳从新到旧去重排序，返回最多 limit 条命令。
func Load(limit int) ([]string, error) {
	return LoadFrom(config.ZshHistoryPath(), limit)
}

func LoadFrom(path string, limit int) ([]string, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, nil
		}
		return nil, err
	}
	text := string(unmetafy(data))

	// 按行分割（兼容 \r、\n、\r\n）
	rawLines := splitLines(text)

	// 合并行尾 \ 续行
	var joined []string
	var buf strings.Builder
	bufHas := false
	for _, line := range rawLines {
		if bufHas {
			buf.WriteByte('\n')
		}
		buf.WriteString(line)
		bufHas = true
		s := buf.String()
		if strings.HasSuffix(s, `\`) {
			buf.Reset()
			buf.WriteString(s[:len(s)-1])
			continue
		}
		joined = append(joined, s)
		buf.Reset()
		bufHas = false
	}
	if bufHas {
		joined = append(joined, buf.String())
	}

	entries := make([]entry, 0, len(joined))
	for i, line := range joined {
		ts, cmd := parseEntry(line)
		if cmd == "" {
			continue
		}
		entries = append(entries, entry{order: i, ts: ts, cmd: cmd})
	}

	// 去重：保留 (ts, order) 最大的（最近）
	best := make(map[string]entry, len(entries))
	for _, e := range entries {
		prev, ok := best[e.cmd]
		if !ok || (e.ts > prev.ts) || (e.ts == prev.ts && e.order > prev.order) {
			best[e.cmd] = e
		}
	}

	unique := make([]entry, 0, len(best))
	for _, e := range best {
		unique = append(unique, e)
	}
	sort.Slice(unique, func(i, j int) bool {
		if unique[i].ts != unique[j].ts {
			return unique[i].ts > unique[j].ts
		}
		return unique[i].order > unique[j].order
	})

	if limit > 0 && len(unique) > limit {
		unique = unique[:limit]
	}
	out := make([]string, len(unique))
	for i, e := range unique {
		out[i] = e.cmd
	}
	return out, nil
}

// 把多种换行符当作分隔符切分（保持和 Python splitlines 一致的简化版）。
func splitLines(s string) []string {
	// 标准化 \r\n -> \n，再把孤立 \r 也当换行
	s = strings.ReplaceAll(s, "\r\n", "\n")
	s = strings.ReplaceAll(s, "\r", "\n")
	if s == "" {
		return nil
	}
	return strings.Split(s, "\n")
}
