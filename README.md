# Uninstall python.org Pythons (macOS)

A tiny **POSIX-sh** script to remove Python versions installed via the official **python.org** macOS installers.  
It’s **safe by default** (dry run). Add `--yes` to actually delete.

---

## What it does

- Finds versions under: `/Library/Frameworks/Python.framework/Versions/<ver>`
- Removes matching app folders: `/Applications/Python <ver>` (IDLE, bundled scripts)
- Deletes `/usr/local/bin` **symlinks** that point into that framework
- Forgets related **pkgutil receipts** (so macOS no longer lists them)

### What it **doesn’t** touch

- Apple’s system Python in `/usr/bin`
- Homebrew Pythons in `/opt/homebrew` or `/usr/local/opt`
- `pyenv`/Conda environments

---

## Usage

Save the script as `uninstall_python_org.sh`, then:

### 1) Preview (dry run)
```sh
sh uninstall_python_org.sh
```

### 2) Remove **all** python.org installs
```sh
sh uninstall_python_org.sh --yes
```

### 3) Remove **specific** versions only
```sh
sh uninstall_python_org.sh --yes --versions 3.10 3.11
```

> Tip: You can use `bash` or `zsh` too — it’s POSIX compatible.

---

## Output & verification

After running, you’ll see what was removed (or would be removed in dry-run).  
Verify your default Python:

```sh
which python3
python3 --version
```

If you’re moving to Homebrew Python:

```sh
brew install python@3.12
brew link --overwrite python@3.12
```

---

## Requirements

- macOS (works with the default `/bin/sh`)
- `sudo` privileges (only required when **actually** deleting with `--yes`)

---

## Uninstall logic (summary)

1. List framework versions in `/Library/Frameworks/Python.framework/Versions`  
2. Optionally filter by `--versions`  
3. Remove `/Applications/Python <ver>`  
4. Remove `/usr/local/bin` symlinks pointing into that framework version  
5. `pkgutil --forget` the receipts for that version

Everything is echoed in dry-run mode so you can see exactly what will happen.

---

## Troubleshooting

- **“command not found: sh”** — use `bash` or `zsh`:
  ```sh
  bash uninstall_python_org.sh --yes
  ```
- **Permission denied** — you’ll be prompted for `sudo` on first deletion.
- **Python still points to old path** — check your shell startup files for custom PATH entries and remove stale overrides.

---

## Licence

MIT — do whatever you like, no warranty.

---

## Disclaimer

Use at your own risk. Read the script before running; it’s short and intentionally conservative.
