# Shell Customization

Files matching `*.sh` in this directory are sourced by zsh on shell startup.

## Usage

1. Copy the example file: `cp aliases.sh.example aliases.sh`
2. Edit `aliases.sh` to add your own aliases, functions, or plugin config
3. Open a new terminal — changes are picked up automatically

## Notes

- Only `*.sh` files are sourced (not `.example` files)
- Files are sourced in alphabetical order
- This directory is tracked by git; add personal-only customizations to `~/.zshrc` instead
