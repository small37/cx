package picker

import (
	"regexp"
	"strings"

	"github.com/charmbracelet/bubbles/textinput"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/muesli/termenv"
)

// Item 给 picker 显示的一行。
type Item struct {
	Command string
	Hint    string // 右侧灰字（标题 / 分类）
}

var dangerPatterns = []*regexp.Regexp{
	regexp.MustCompile(`\bsudo\b`),
	regexp.MustCompile(`\brm\s+-rf\b`),
	regexp.MustCompile(`\bchmod\s+777\b`),
	regexp.MustCompile(`\bdd\s+if=`),
	regexp.MustCompile(`\bmkfs\b`),
	regexp.MustCompile(`\bdiskutil\s+erase`),
}

func IsDangerous(cmd string) bool {
	for _, p := range dangerPatterns {
		if p.MatchString(cmd) {
			return true
		}
	}
	return false
}

// Match 空格分词 AND 匹配（大小写不敏感）。
func Match(command, query string) bool {
	terms := matchTerms(query)
	if len(terms) == 0 {
		return true
	}
	return matchPrepared(strings.ToLower(command), terms)
}

func matchTerms(query string) []string {
	return strings.Fields(strings.ToLower(strings.TrimSpace(query)))
}

func matchPrepared(commandLower string, terms []string) bool {
	for _, part := range terms {
		if !strings.Contains(commandLower, part) {
			return false
		}
	}
	return true
}

// --- styles ---

var (
	accent  = lipgloss.Color("#7aa2f7") // 主色（蓝）
	accent2 = lipgloss.Color("#bb9af7") // 紫
	muted   = lipgloss.Color("#565f89") // 暗灰
	textFg  = lipgloss.Color("#c0caf5") // 主文本
	subtle  = lipgloss.Color("#9aa5ce") // 次要文本
	danger  = lipgloss.Color("#f7768e") // 危险红
	ok      = lipgloss.Color("#9ece6a") // 序号绿
	warn    = lipgloss.Color("#e0af68") // 黄

	panelStyle = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(accent).
			Padding(0, 1)

	titleStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(lipgloss.Color("#1a1b26")).
			Background(accent).
			Padding(0, 1)

	searchLabelStyle = lipgloss.NewStyle().Foreground(accent2).Bold(true)
	searchTextStyle  = lipgloss.NewStyle().Foreground(textFg)
	frameStyle       = lipgloss.NewStyle().Foreground(muted)

	selectedStyle = lipgloss.NewStyle().
			Background(accent2).
			Foreground(lipgloss.Color("#1a1b26")).
			Bold(true)
	selectedHintStyle = lipgloss.NewStyle().
				Background(accent2).
				Foreground(lipgloss.Color("#1a1b26")).
				Italic(true)

	numStyle     = lipgloss.NewStyle().Foreground(ok)
	markerStyle  = lipgloss.NewStyle().Foreground(accent2).Bold(true)
	cmdStyle     = lipgloss.NewStyle().Foreground(textFg)
	dangerStyle  = lipgloss.NewStyle().Foreground(danger).Bold(true)
	hintStyle    = lipgloss.NewStyle().Foreground(subtle).Italic(true)
	footerStyle  = lipgloss.NewStyle().Foreground(warn)
	emptyStyle   = lipgloss.NewStyle().Foreground(muted).Italic(true)
	counterStyle = lipgloss.NewStyle().Foreground(subtle)
)

const (
	listMax     = 15
	chromeLines = 6 // 边框 2 + 标题 1 + 分隔 1 + footer 1 + padding 1
)

type model struct {
	title    string
	items    []Item
	display  []string
	match    []string
	danger   []bool
	filtered []int
	idx      int
	offset   int
	width    int
	listH    int // 实际渲染的列表行数

	input    textinput.Model
	selected string
	canceled bool
	done     bool
}

func newModel(title string, items []Item) model {
	ti := textinput.New()
	ti.Placeholder = ""
	ti.Prompt = ""
	ti.Focus()
	ti.CharLimit = 0

	m := model{
		title:   title,
		items:   items,
		display: make([]string, len(items)),
		match:   make([]string, len(items)),
		danger:  make([]bool, len(items)),
		input:   ti,
		listH:   listMax,
	}
	for i, it := range items {
		m.display[i] = singleLinePreview(it.Command)
		m.match[i] = strings.ToLower(it.Command)
		m.danger[i] = IsDangerous(m.display[i])
	}
	m.refilter()
	return m
}

func (m *model) refilter() {
	terms := matchTerms(m.input.Value())
	m.filtered = m.filtered[:0]
	for i, text := range m.match {
		if matchPrepared(text, terms) {
			m.filtered = append(m.filtered, i)
		}
	}
	m.idx = 0
	m.offset = 0
}

func (m *model) clampOffset() {
	if len(m.filtered) == 0 {
		m.offset = 0
		return
	}
	if m.idx < m.offset {
		m.offset = m.idx
	} else if m.idx >= m.offset+m.listH {
		m.offset = m.idx - m.listH + 1
	}
	maxOff := len(m.filtered) - m.listH
	if maxOff < 0 {
		maxOff = 0
	}
	if m.offset > maxOff {
		m.offset = maxOff
	}
	if m.offset < 0 {
		m.offset = 0
	}
}

func (m model) Init() tea.Cmd { return textinput.Blink }

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		h := listMax
		maxByHeight := msg.Height - chromeLines
		if maxByHeight < 3 {
			maxByHeight = 3
		}
		if h > maxByHeight {
			h = maxByHeight
		}
		m.listH = h
		return m, nil

	case tea.KeyMsg:
		switch msg.String() {
		case "esc", "ctrl+c":
			m.canceled = true
			m.done = true
			return m, tea.Quit
		case "enter", "tab":
			if len(m.filtered) > 0 {
				m.selected = m.items[m.filtered[m.idx]].Command
			}
			m.done = true
			return m, tea.Quit
		case "up", "ctrl+p":
			if len(m.filtered) > 0 {
				m.idx--
				if m.idx < 0 {
					m.idx = len(m.filtered) - 1
				}
			}
			return m, nil
		case "down", "ctrl+n":
			if len(m.filtered) > 0 {
				m.idx = (m.idx + 1) % len(m.filtered)
			}
			return m, nil
		case "pgup":
			if len(m.filtered) > 0 {
				m.idx -= m.listH
				if m.idx < 0 {
					m.idx = 0
				}
			}
			return m, nil
		case "pgdown":
			if len(m.filtered) > 0 {
				m.idx += m.listH
				if m.idx >= len(m.filtered) {
					m.idx = len(m.filtered) - 1
				}
			}
			return m, nil
		case "home":
			m.idx = 0
			return m, nil
		case "end":
			if len(m.filtered) > 0 {
				m.idx = len(m.filtered) - 1
			}
			return m, nil
		case "ctrl+u":
			m.input.SetValue("")
			m.refilter()
			return m, nil
		}
	}

	prev := m.input.Value()
	var cmd tea.Cmd
	m.input, cmd = m.input.Update(msg)
	if m.input.Value() != prev {
		m.refilter()
	}
	return m, cmd
}

func (m model) View() string {
	if m.done {
		return ""
	}
	m.clampOffset()

	// 内容区目标宽度（去掉边框 2 列 + 左右 padding 2 列）
	outerW := m.width
	if outerW < 40 {
		outerW = 80
	}
	if outerW > 160 {
		outerW = 160
	}
	contentW := outerW - 4
	if contentW < 20 {
		contentW = 20
	}

	var b strings.Builder

	// 顶部：标题徽章 + 计数 + 搜索框
	total := len(m.filtered)
	counter := ""
	if total > 0 {
		counter = counterStyle.Render("  " + itoa(m.idx+1) + "/" + itoa(total))
	} else {
		counter = counterStyle.Render("  0/0")
	}
	head := titleStyle.Render(m.title) + counter
	b.WriteString(head + "\n")

	// 搜索框
	searchLine := searchLabelStyle.Render(" 搜索 ") +
		searchTextStyle.Render(m.input.View())
	b.WriteString(searchLine + "\n")

	// 分隔线
	b.WriteString(frameStyle.Render(strings.Repeat("─", contentW)) + "\n")

	// 列表
	if len(m.filtered) == 0 {
		b.WriteString(emptyStyle.Render("  (无匹配)"))
		b.WriteByte('\n')
		for i := 1; i < m.listH; i++ {
			b.WriteByte('\n')
		}
	} else {
		end := m.offset + m.listH
		if end > len(m.filtered) {
			end = len(m.filtered)
		}
		for row := m.offset; row < end; row++ {
			itemIdx := m.filtered[row]
			it := m.items[itemIdx]
			isSel := row == m.idx
			b.WriteString(renderRow(row, it, m.display[itemIdx], m.danger[itemIdx], isSel, contentW))
			b.WriteByte('\n')
		}
		for i := end - m.offset; i < m.listH; i++ {
			b.WriteByte('\n')
		}
	}

	// 底部
	b.WriteString(frameStyle.Render(strings.Repeat("─", contentW)) + "\n")
	b.WriteString(footerStyle.Render("Enter 选中") +
		hintStyle.Render("  ·  ") +
		footerStyle.Render("↑↓ 移动") +
		hintStyle.Render("  ·  ") +
		footerStyle.Render("PgUp/PgDn 翻页") +
		hintStyle.Render("  ·  ") +
		footerStyle.Render("Esc 退出"))

	return panelStyle.Render(b.String())
}

// 渲染单行；isSel 时整行底色，否则正常着色，并补足末尾空白以保证选中底色一直延伸到行尾。
func renderRow(row int, it Item, cmd string, dangerous bool, isSel bool, w int) string {
	marker := "  "
	if isSel {
		marker = "▶ "
	}
	numTxt := padLeft(itoa(row+1), 3) + "  "
	hint := it.Hint

	// 计算可见宽度，必要时截断命令文本，留空间给 hint
	prefix := " " + marker + numTxt // 含一格内左留白
	prefixW := lipgloss.Width(prefix)

	hintPart := ""
	hintW := 0
	if hint != "" {
		hintPart = "   " + hint
		hintW = lipgloss.Width(hintPart)
	}

	avail := w - prefixW - hintW
	if avail < 4 {
		avail = 4
		hintPart = ""
		hintW = 0
	}
	cmdDisp := truncate(cmd, avail)
	// 计算填充到行尾的空格，让选中底色铺满
	used := prefixW + lipgloss.Width(cmdDisp) + hintW
	pad := w - used
	if pad < 0 {
		pad = 0
	}

	if isSel {
		left := selectedStyle.Render(" " + marker + numTxt + cmdDisp)
		var right string
		if hintPart != "" {
			right = selectedHintStyle.Render(hintPart)
		}
		filler := selectedStyle.Render(strings.Repeat(" ", pad))
		return left + right + filler
	}

	markerR := markerStyle.Render(marker)
	if marker == "  " {
		markerR = "  "
	}
	numR := numStyle.Render(numTxt)
	cmdStyleUse := cmdStyle
	if dangerous {
		cmdStyleUse = dangerStyle
	}
	cmdR := cmdStyleUse.Render(cmdDisp)
	hintR := ""
	if hintPart != "" {
		hintR = hintStyle.Render(hintPart)
	}
	return " " + markerR + numR + cmdR + hintR + strings.Repeat(" ", pad)
}

// truncate 按显示宽度截断字符串，超出时末尾加省略号。
func truncate(s string, w int) string {
	if lipgloss.Width(s) <= w {
		return s
	}
	if w <= 1 {
		return "…"
	}
	// 按 rune 逐个累加宽度
	out := make([]rune, 0, len(s))
	cur := 0
	for _, r := range s {
		rw := lipgloss.Width(string(r))
		if cur+rw+1 > w { // 留 1 给 …
			break
		}
		out = append(out, r)
		cur += rw
	}
	return string(out) + "…"
}

func singleLinePreview(s string) string {
	s = strings.ReplaceAll(s, "\r\n", "\n")
	s = strings.ReplaceAll(s, "\r", "\n")
	if i := strings.IndexByte(s, '\n'); i >= 0 {
		return s[:i] + "…"
	}
	return s
}

// Run 半屏运行 picker。返回选中的命令字符串（空字符串表示取消）。
func Run(title string, items []Item) (string, error) {
	if len(items) == 0 {
		return "", nil
	}
	// 当 stdout 被 $() 捕获时，lipgloss 默认降级色彩。强制 TrueColor
	// 让 zsh 包装与直接调用视觉一致（Ghostty 支持 24bit 色）。
	lipgloss.SetColorProfile(termenv.TrueColor)

	m := newModel(title, items)
	// 半屏 inline：不开 AltScreen；让 bubbletea 在当前光标位置往下渲染。
	p := tea.NewProgram(m, tea.WithInput(openTTY()), tea.WithOutput(ttyOut()))
	final, err := p.Run()
	if err != nil {
		return "", err
	}
	fm := final.(model)
	if fm.canceled {
		return "", nil
	}
	return fm.selected, nil
}

// itoa / padLeft 减少 fmt 依赖。
func itoa(n int) string {
	if n == 0 {
		return "0"
	}
	neg := false
	if n < 0 {
		neg = true
		n = -n
	}
	var buf [20]byte
	i := len(buf)
	for n > 0 {
		i--
		buf[i] = byte('0' + n%10)
		n /= 10
	}
	if neg {
		i--
		buf[i] = '-'
	}
	return string(buf[i:])
}

func padLeft(s string, w int) string {
	if len(s) >= w {
		return s
	}
	return strings.Repeat(" ", w-len(s)) + s
}
