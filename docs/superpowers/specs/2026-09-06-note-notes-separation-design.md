# Design: separate `note` (code) and `notes` (data) across machines

## Context

The `,note` CLI (Python + Vim) appends timestamped entries to notes files and
auto-commits them nightly via cron. Two repos are involved:

- `~/Development/note` — public GitHub repo, the tool's source code
  (`,note`, `notes.vim`, `install.sh`, `git_auto_commit.sh`, `README.md`).
- `~/Development/notes` (moving to `~/Documents/notes`) — private GitHub repo,
  real note data (`notes.txt`, `personal_notes.txt`, dated files). Git history
  shows a working nightly auto-commit/push cron through 2025-08-07 that
  stopped (machine reset); the repo was just re-cloned fresh on this machine.

The original design assumed one repo at `~/notes` containing both code and
data (`install.sh` hardcodes `~/notes/,note`; `git_auto_commit.sh` hardcodes
`cd ~/notes`). The goal now is a clean code/data split, used across
**multiple machines**, with no duplicated code between the two repos.

The editor is Neovim via LazyVim (`$EDITOR=nvim` already set; config lives at
`~/.config/nvim`, itself symlinked to `~/.workspace-settings/nvim`), not the
classic Vim the original README/`.vimrc` snippet targeted.

## Audit: is any data at risk, and which repo's code is current?

Before finalizing the split, `notes` was audited directly:

- **Data safety confirmed.** `git status` in `notes` is clean — no
  uncommitted changes, no stash. `.rye_notes.txt.swp`/`.swo` are stale Vim
  crash artifacts from a March 2025 session on a different machine
  (`Andrews-MacBook-Pro-M3.local`, path `~andrew/Developer/notes/`); every
  distinctive line inside them was confirmed already present in the
  committed `rye_notes.txt`. Untracking (or deleting) them loses nothing.
- **`notes`'s code had diverged and was more current than `note`'s** for 3
  of 5 shared files (`note` hasn't been touched since its 2025-02-28 initial
  commit; `notes` kept evolving through 2025-03-19):
  - `,note` — reworked to use a `REPO_DIR`-relative path instead of
    `~/notes`, split output into `rye_notes.txt` (work) +
    `personal_notes.txt`, and marked the per-day dated-file function
    `DEPRECATED` (it was already dead code — no CLI flag ever called it).
  - `install.sh` — computes its own directory via `BASH_SOURCE` and only
    creates the `~/bin/,note` symlink if it doesn't already exist
    (idempotent).
  - `git_auto_commit.sh` — `cd`s to `$HOME/Developer/notes` — this is
    **not** an improvement, just a different machine's hardcoded path
    (note "Developer" vs this machine's "Development"/"Documents").
  - `notes.vim` — identical in both repos.
  - `README.md` — rewritten in `notes` with a philosophy blurb, and ends
    with a TODO: *"How do git submodules work. Can this be split up into
    submodule so that the app can stay public while the notes can stay
    private?"* — i.e. this exact code/data split question was already
    raised once, unresolved, six months ago.

Resolved with the user:
- Drop the per-day dated-file concept entirely (delete the function, don't
  just deprecate it).
- Go back to one master `notes.txt` + `personal_notes.txt` under a fixed
  `NOTES_DIR`, not the `REPO_DIR`/`rye_notes.txt` split. `rye_notes.txt`
  becomes a closed-out historical file — kept in the repo, never written to
  again.
- Adopt `install.sh`'s idempotent-symlink check (real improvement).
- Do **not** adopt `git_auto_commit.sh`'s `~/Developer/notes` path (that
  machine's bug, not this design's).

## Decisions

1. **No vendoring.** `notes` never carries a copy of the scripts — all code
   lives only in `note`. (An earlier "self-contained notes" idea was
   rejected once duplication/drift risk came up.)
2. **Fixed path convention, not an env var.** Every machine clones `note` to
   `~/Development/note` and `notes` to `~/Documents/notes`. Scripts hardcode
   these paths rather than reading a config value.
3. **Auto `git pull --rebase`** before the nightly commit/push, to absorb the
   common multi-machine case (two machines both only appended lines) without
   manual intervention. A genuine conflict still aborts and logs, as today.
4. **Fix a latent bug** found during investigation: no `.gitignore` in
   `notes`, so the nightly `git add -A` has already committed stray Vim swap
   files (`.rye_notes.txt.swp`/`.swo` are tracked right now).
5. **Master `notes.txt` model wins**, not the `notes` repo's `REPO_DIR`/
   `rye_notes.txt` split (see audit above). `rye_notes.txt` is retired as a
   historical file.
6. **Per-day dated files are removed**, not just deprecated — dead code,
   confirmed no CLI path reaches it.

## Design

### `~/Development/note` (code repo)

- **`,note`** — change `notes_dir` from `~/notes` to a constant:
  `NOTES_DIR = os.path.join(os.path.expanduser("~"), "Documents", "notes")`,
  used by `get_filename_for_master_file()` and
  `get_filename_for_personal_notes()`. Delete `get_filename_for_today()` and
  its Year/Month dated-file logic entirely — no `REPO_DIR`/`COMPANY_NAME`
  concept, no dated-file mode.
- **`git_auto_commit.sh`** — `cd ~/Documents/notes` (was `~/notes`; **not**
  `notes`'s `~/Developer/notes` — that was another machine's hardcoded
  path); add `git pull --rebase` immediately before `git add -A`.
- **`install.sh`** — symlink `~/bin/,note` → `~/Development/note/,note` (was
  `~/notes/,note`), guarded so it only creates the symlink if
  `~/bin/,note` doesn't already exist (idempotency adopted from `notes`'s
  version); keep the `$PATH` check (currently a no-op — `~/bin` is already
  on `$PATH`); crontab line now points at
  `~/Development/note/git_auto_commit.sh`, logging to
  `~/Documents/notes/git_auto_commit.log`.
- **New `nvim/notes_tool.lua`** — one Lua module bundling:
  - a `BufRead`/`BufNewFile` autocmd setting `filetype=notes` for
    `~/Documents/notes/notes.txt` and `~/Documents/notes/personal_notes.txt`
    only (no dated-file pattern — that mode is removed, see decision 6)
  - a buffer-local `<leader>t` keymap (ported from the old `.vimrc`'s
    `InsertTimestamp()`), scoped to the `notes` filetype only
  - exported as `M.setup()`
- `notes.vim` (syntax file) is unchanged — it becomes the canonical copy
  Neovim reads via symlink (below).

### `~/Documents/notes` (data repo)

- New `.gitignore`: `*.swp` / `*.swo`.
- `git rm --cached .rye_notes.txt.swp .rye_notes.txt.swo` (untrack, keep the
  local files on disk), committed alongside the `.gitignore` add. Verified
  safe to untrack — see audit above.
- `rye_notes.txt` stays in the repo as a closed-out historical file — no
  script writes to it going forward. `notes.txt` (181KB, last grown before
  the `notes` repo's `,note` diverged) resumes being the active file.
- No script files added here — confirms the no-vendoring decision.

### `~/.config/nvim` (LazyVim config — separate from both repos above)

- `~/.config/nvim/syntax/notes.vim` → **symlink** to
  `~/Development/note/notes.vim` (not a copy — single source of truth).
- `~/.config/nvim/lua/notes_tool.lua` → **symlink** to
  `~/Development/note/nvim/notes_tool.lua`.
- One line appended to the existing (currently empty template)
  `~/.config/nvim/lua/config/autocmds.lua`: `require("notes_tool").setup()`.

### System state (per machine)

- `mv ~/Development/notes ~/Documents/notes` (this machine only; other
  machines just clone straight to `~/Documents/notes`).
- `ln -s ~/Development/note/,note ~/bin/,note`.
- `crontab`: `59 23 * * * $HOME/Development/note/git_auto_commit.sh >> $HOME/Documents/notes/git_auto_commit.log 2>&1`.
- In both `note` and `notes`, set the local git identity so commits (and the
  nightly auto-commit) aren't attributed to a work email inherited from
  global config: `git config user.email andrew.parmar@gmail.com` (repo-local
  only, global config untouched).

## Verification

- `,note` → creates/opens `~/Documents/notes/notes.txt` in `nvim`, cursor at
  end, insert mode, `NoteDate`/`TodoItem`/`CompletedItem`/`BulletItem`
  highlighting visible, `:set filetype?` → `notes`.
- `,note -r` → read-only, no new entry appended.
- `,note --todo` → greps `†` lines.
- `<leader>t` in a notes buffer → inserts a formatted timestamp; confirm it
  does *not* fire in a non-notes buffer.
- `crontab -l` → shows the restored line pointing at the new paths.
- Manually run `~/Development/note/git_auto_commit.sh` once → confirm
  `git pull --rebase` + commit + push succeed cleanly against
  `git@github.com:andrewparmar/notes.git`, with no swap files in the diff.
- Walk through the same install steps for a second machine on paper —
  confirm nothing still assumes a machine-specific path outside the two
  fixed conventions (`~/Development/note`, `~/Documents/notes`).
- `rye_notes.txt` is byte-identical before and after the cutover (nothing
  ever writes to it again); `notes.txt` gains new entries on the next
  `,note` run.
