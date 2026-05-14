# CX zsh integration
# Source this file in ~/.zshrc:  source "/Users/one/Documents/项目/测试2/cx-go/integrations/cx.zsh"

# 包一层 `cx`，让选完命令落到下一行光标位置（而不是打印到上方）。
# 其它子命令（add/edit/del/list/fav）透传到二进制。
cx() {
  local sub="${1:-}"
  case "$sub" in
    ""|history|h|fav|f)
      local _cmd _tmp
      _tmp="$(mktemp -t cx_pick.XXXXXX)" || return 1
      command cx "$@" >"$_tmp"
      _cmd="$(<"$_tmp")"
      rm -f -- "$_tmp"
      if [[ -n "$_cmd" ]]; then
        # 压入 zle 缓冲栈，在下一次提示符直接出现在输入行，便于继续编辑。
        print -zr -- "$_cmd"
      fi
      ;;
    *)
      command cx "$@"
      ;;
  esac
}

# Ctrl+R 绑定：用 cx history 替换 zsh 默认的反向搜索
_cx_history_widget() {
  local _cmd
  _cmd=$(command cx history)
  zle reset-prompt
  if [[ -n "$_cmd" ]]; then
    LBUFFER+=$_cmd
  fi
}
zle -N _cx_history_widget
bindkey '^R' _cx_history_widget
