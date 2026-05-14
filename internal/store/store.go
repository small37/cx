package store

import (
	"database/sql"
	"strings"
	"time"

	_ "modernc.org/sqlite"

	"github.com/one/cx/internal/config"
)

const schema = `
CREATE TABLE IF NOT EXISTS favorites (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT,
    command TEXT NOT NULL,
    description TEXT,
    category TEXT,
    sort_order INTEGER DEFAULT 0,
    use_count INTEGER DEFAULT 0,
    created_at TEXT,
    updated_at TEXT
);`

type Favorite struct {
	ID          int64
	Title       string
	Command     string
	Description string
	Category    string
	SortOrder   int
	UseCount    int
}

type Store struct {
	db *sql.DB
}

func Open() (*Store, error) {
	if err := config.EnsureDirs(); err != nil {
		return nil, err
	}
	db, err := sql.Open("sqlite", config.DBPath())
	if err != nil {
		return nil, err
	}
	if _, err := db.Exec(schema); err != nil {
		db.Close()
		return nil, err
	}
	return &Store{db: db}, nil
}

func (s *Store) Close() error { return s.db.Close() }

func nowISO() string { return time.Now().Format("2006-01-02T15:04:05") }

func (s *Store) List() ([]Favorite, error) {
	return s.list(0)
}

func (s *Store) ListLimit(limit int) ([]Favorite, error) {
	return s.list(limit)
}

func (s *Store) list(limit int) ([]Favorite, error) {
	q := `SELECT id, COALESCE(title,''), command, COALESCE(description,''), COALESCE(category,''), COALESCE(sort_order,0), COALESCE(use_count,0) FROM favorites ORDER BY sort_order ASC, id ASC`
	args := []any{}
	if limit > 0 {
		q += ` LIMIT ?`
		args = append(args, limit)
	}
	rows, err := s.db.Query(q, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Favorite
	for rows.Next() {
		var f Favorite
		if err := rows.Scan(&f.ID, &f.Title, &f.Command, &f.Description, &f.Category, &f.SortOrder, &f.UseCount); err != nil {
			return nil, err
		}
		out = append(out, f)
	}
	return out, rows.Err()
}

func (s *Store) Add(f Favorite) (int64, error) {
	ts := nowISO()
	if f.SortOrder == 0 {
		row := s.db.QueryRow(`SELECT COALESCE(MAX(sort_order),0)+1 FROM favorites`)
		_ = row.Scan(&f.SortOrder)
	}
	res, err := s.db.Exec(
		`INSERT INTO favorites (title, command, description, category, sort_order, use_count, created_at, updated_at) VALUES (?,?,?,?,?,0,?,?)`,
		f.Title, f.Command, f.Description, f.Category, f.SortOrder, ts, ts,
	)
	if err != nil {
		return 0, err
	}
	return res.LastInsertId()
}

// UpdateFields 部分更新；nil 表示不变。
type UpdateFields struct {
	Title       *string
	Command     *string
	Description *string
	Category    *string
	SortOrder   *int
}

func (s *Store) Update(id int64, u UpdateFields) (bool, error) {
	sets := []string{}
	args := []any{}
	if u.Title != nil {
		sets = append(sets, "title = ?")
		args = append(args, *u.Title)
	}
	if u.Command != nil {
		sets = append(sets, "command = ?")
		args = append(args, *u.Command)
	}
	if u.Description != nil {
		sets = append(sets, "description = ?")
		args = append(args, *u.Description)
	}
	if u.Category != nil {
		sets = append(sets, "category = ?")
		args = append(args, *u.Category)
	}
	if u.SortOrder != nil {
		sets = append(sets, "sort_order = ?")
		args = append(args, *u.SortOrder)
	}
	if len(sets) == 0 {
		return false, nil
	}
	sets = append(sets, "updated_at = ?")
	args = append(args, nowISO(), id)
	q := "UPDATE favorites SET " + strings.Join(sets, ", ") + " WHERE id = ?"
	res, err := s.db.Exec(q, args...)
	if err != nil {
		return false, err
	}
	n, _ := res.RowsAffected()
	return n > 0, nil
}

func (s *Store) Delete(id int64) (bool, error) {
	res, err := s.db.Exec(`DELETE FROM favorites WHERE id = ?`, id)
	if err != nil {
		return false, err
	}
	n, _ := res.RowsAffected()
	return n > 0, nil
}

func (s *Store) BumpUse(id int64) error {
	_, err := s.db.Exec(`UPDATE favorites SET use_count = use_count + 1, updated_at = ? WHERE id = ?`, nowISO(), id)
	return err
}
