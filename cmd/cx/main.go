package main

import (
	"bufio"
	"fmt"
	"os"
	"strconv"
	"strings"

	"github.com/spf13/cobra"

	"github.com/one/cx/internal/history"
	"github.com/one/cx/internal/picker"
	"github.com/one/cx/internal/store"
)

func main() {
	root := newRootCmd()
	if err := root.Execute(); err != nil {
		os.Exit(1)
	}
}

func newRootCmd() *cobra.Command {
	root := &cobra.Command{
		Use:           "cx",
		Short:         "CX - terminal command picker",
		SilenceUsage:  true,
		SilenceErrors: true,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runHistory()
		},
	}
	root.AddCommand(
		newHistoryCmd(),
		newAliasCmd("h", "history (短命令)", runHistory),
		newFavCmd(),
		newAliasCmd("f", "fav (短命令)", runFav),
		newAddCmd(),
		newEditCmd(),
		newDelCmd(),
		newListCmd(),
	)
	return root
}

func newAliasCmd(name, short string, fn func() error) *cobra.Command {
	return &cobra.Command{
		Use:    name,
		Short:  short,
		Hidden: true,
		RunE:   func(cmd *cobra.Command, args []string) error { return fn() },
	}
}

func newHistoryCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "history",
		Short: "打开历史命令选择器",
		RunE:  func(cmd *cobra.Command, args []string) error { return runHistory() },
	}
}

func newFavCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "fav",
		Short: "打开常用命令选择器",
		RunE:  func(cmd *cobra.Command, args []string) error { return runFav() },
	}
}

func runHistory() error {
	cmds, err := history.Load(100)
	if err != nil {
		return err
	}
	if len(cmds) == 0 {
		fmt.Fprintln(os.Stderr, "(没有历史命令)")
		return nil
	}
	items := make([]picker.Item, len(cmds))
	for i, c := range cmds {
		items[i] = picker.Item{Command: c}
	}
	sel, err := picker.Run("CX 历史命令", items)
	if err != nil {
		return err
	}
	if sel != "" {
		fmt.Println(sel)
	}
	return nil
}

func runFav() error {
	s, err := store.Open()
	if err != nil {
		return err
	}
	defer s.Close()
	favs, err := s.ListLimit(100)
	if err != nil {
		return err
	}
	if len(favs) == 0 {
		fmt.Fprintln(os.Stderr, "(还没有收藏命令，用 `cx add` 添加)")
		return nil
	}
	items := make([]picker.Item, len(favs))
	for i, f := range favs {
		hint := f.Title
		if hint == "" {
			hint = f.Category
		}
		items[i] = picker.Item{Command: f.Command, Hint: hint}
	}
	sel, err := picker.Run("CX 常用命令", items)
	if err != nil {
		return err
	}
	if sel != "" {
		fmt.Println(sel)
	}
	return nil
}

func newAddCmd() *cobra.Command {
	var title, desc, category string
	cmd := &cobra.Command{
		Use:   "add [command]",
		Short: "添加常用命令",
		RunE: func(cmd *cobra.Command, args []string) error {
			s, err := store.Open()
			if err != nil {
				return err
			}
			defer s.Close()

			command := strings.Join(args, " ")
			rd := bufio.NewReader(os.Stdin)
			if command == "" {
				command = ask(rd, "命令: ")
				if command == "" {
					fmt.Fprintln(os.Stderr, "空命令，已取消")
					return nil
				}
				if title == "" {
					title = ask(rd, "标题（可空）: ")
				}
				if desc == "" {
					desc = ask(rd, "说明（可空）: ")
				}
				if category == "" {
					category = ask(rd, "分类（可空）: ")
				}
			}
			id, err := s.Add(store.Favorite{
				Title: title, Command: command, Description: desc, Category: category,
			})
			if err != nil {
				return err
			}
			fmt.Printf("已添加 #%d: %s\n", id, command)
			return nil
		},
	}
	cmd.Flags().StringVarP(&title, "title", "t", "", "标题")
	cmd.Flags().StringVarP(&desc, "desc", "d", "", "说明")
	cmd.Flags().StringVarP(&category, "category", "c", "", "分类")
	return cmd
}

func newEditCmd() *cobra.Command {
	var title, command, desc, category string
	cmd := &cobra.Command{
		Use:   "edit <id>",
		Short: "编辑常用命令",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			id, err := strconv.ParseInt(args[0], 10, 64)
			if err != nil {
				return fmt.Errorf("无效 ID: %s", args[0])
			}
			s, err := store.Open()
			if err != nil {
				return err
			}
			defer s.Close()
			var u store.UpdateFields
			if cmd.Flags().Changed("title") {
				u.Title = &title
			}
			if cmd.Flags().Changed("command") {
				u.Command = &command
			}
			if cmd.Flags().Changed("desc") {
				u.Description = &desc
			}
			if cmd.Flags().Changed("category") {
				u.Category = &category
			}
			ok, err := s.Update(id, u)
			if err != nil {
				return err
			}
			if !ok {
				fmt.Fprintln(os.Stderr, "未更新（ID 不存在或未提供字段）")
				os.Exit(1)
			}
			fmt.Printf("已更新 #%d\n", id)
			return nil
		},
	}
	cmd.Flags().StringVar(&command, "command", "", "命令")
	cmd.Flags().StringVarP(&title, "title", "t", "", "标题")
	cmd.Flags().StringVarP(&desc, "desc", "d", "", "说明")
	cmd.Flags().StringVarP(&category, "category", "c", "", "分类")
	return cmd
}

func newDelCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "del <id>",
		Short: "删除常用命令",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			id, err := strconv.ParseInt(args[0], 10, 64)
			if err != nil {
				return fmt.Errorf("无效 ID: %s", args[0])
			}
			s, err := store.Open()
			if err != nil {
				return err
			}
			defer s.Close()
			ok, err := s.Delete(id)
			if err != nil {
				return err
			}
			if !ok {
				fmt.Fprintln(os.Stderr, "未找到该 ID")
				os.Exit(1)
			}
			fmt.Printf("已删除 #%d\n", id)
			return nil
		},
	}
}

func newListCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "list",
		Short: "列出收藏命令",
		RunE: func(cmd *cobra.Command, args []string) error {
			s, err := store.Open()
			if err != nil {
				return err
			}
			defer s.Close()
			favs, err := s.List()
			if err != nil {
				return err
			}
			if len(favs) == 0 {
				fmt.Println("(空)")
				return nil
			}
			for _, f := range favs {
				fmt.Printf("#%3d  %-20s  %s\n", f.ID, f.Title, f.Command)
			}
			return nil
		},
	}
}

func ask(rd *bufio.Reader, prompt string) string {
	fmt.Fprint(os.Stderr, prompt)
	line, err := rd.ReadString('\n')
	if err != nil {
		return strings.TrimSpace(line)
	}
	return strings.TrimSpace(line)
}
