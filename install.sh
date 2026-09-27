#!/bin/sh
# install.sh — link the herdr wrappers into ~/.local/bin and the roles into ~/.claude/agents.
#
#   ./install.sh            link everything, report what changed
#   ./install.sh --check    report what would change, touch nothing
#   BIN_DIR=/somewhere ./install.sh     link into a different directory
#
# Links rather than copies, so `git pull` in this checkout updates the installed
# tools with no second step. That is also why the checkout has to stay where it is:
# move it and the links break. The roles are linked the same way, one link per file,
# so `git pull` updates them too — and the agent that reads its definition at start
# keeps the old one until it is re-hired.

set -eu

REPO_DIR=$(cd "$(dirname "$0")" && pwd)
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
AGENTS_DIR="${AGENTS_DIR:-$HOME/.claude/agents}"
CHECK=0
[ "${1:-}" = "--check" ] && CHECK=1

TOOLS="recruit roster fire tell await await-mr"

changed=0
note() { printf '%s\n' "$*"; }

link_one() {
    src="$1"
    dst="$2"
    if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
        note "ok       $(basename "$dst")"
        return 0
    fi
    changed=$((changed + 1))
    if [ "$CHECK" = "1" ]; then
        if [ -e "$dst" ] || [ -L "$dst" ]; then
            note "differs  $(basename "$dst") -> would be relinked"
        else
            note "missing  $(basename "$dst") -> would be created"
        fi
        return 0
    fi
    # An existing regular file is somebody's own copy; keep it rather than destroy it.
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        backup="$dst.backup-$(date +%Y%m%d-%H%M%S)"
        mv "$dst" "$backup"
        note "kept     $(basename "$dst") as $(basename "$backup")"
    fi
    rm -f "$dst"
    ln -s "$src" "$dst"
    note "linked   $(basename "$dst")"
}

mkdir -p "$BIN_DIR"

# ~/.claude/agents may itself be a link into somebody's own repository; a role linked
# into a linked directory lands in that repository, which is not what anybody wants.
if [ -L "$AGENTS_DIR" ]; then
    echo "install.sh: $AGENTS_DIR is a symbolic link to $(readlink "$AGENTS_DIR"); make it a directory first" >&2
    exit 1
fi
mkdir -p "$AGENTS_DIR"

for tool in $TOOLS; do
    [ -f "$REPO_DIR/bin/$tool" ] || { echo "install.sh: $REPO_DIR/bin/$tool is missing" >&2; exit 1; }
    chmod +x "$REPO_DIR/bin/$tool"
    link_one "$REPO_DIR/bin/$tool" "$BIN_DIR/$tool"
done

for role in "$REPO_DIR"/agents/*.md; do
    link_one "$role" "$AGENTS_DIR/$(basename "$role")"
done

note ""
if [ "$CHECK" = "1" ]; then
    [ "$changed" = "0" ] && note "everything is linked" || note "$changed link(s) would change — run ./install.sh"
    exit 0
fi
[ "$changed" = "0" ] && note "everything was already linked" || note "$changed link(s) updated"

# Prerequisites. Every wrapper drives agents in herdr panes and does nothing without it,
# so a missing herdr is not a note here: the links are in place, but the installation is
# not usable, and the exit code says so. The rest are notes — the orchestrator degrades
# without glab and without the developer set, it does not stop.
note ""
note "Prerequisites:"
missing=0

case ":$PATH:" in
    *":$BIN_DIR:"*) note "  ok    $BIN_DIR is on your PATH" ;;
    *) note "  MISS  $BIN_DIR is not on your PATH — add it to your shell profile" ;;
esac

if command -v herdr >/dev/null 2>&1; then
    note "  ok    herdr — the wrappers can run"
else
    note "  MISS  herdr — nothing here works without it. Install it from https://herdr.dev"
    missing=1
fi

if command -v glab >/dev/null 2>&1; then
    note "  ok    glab — await-mr can watch merge requests"
else
    note "  MISS  glab — only await-mr needs it (brew install glab, then glab auth login)"
fi

if command -v clickup >/dev/null 2>&1; then
    note "  ok    clickup — the developer set is installed"
else
    note "  MISS  clickup — install the developer set first: https://github.com/TechTechWizard/claude-work-tools"
fi

if [ -f "$HOME/.claude/skills/orchestrator/SKILL.md" ]; then
    note "  ok    the orchestrator skill is installed"
else
    note "  MISS  the orchestrator skill — npx skills add TechTechWizard/orchestrator -g -a claude-code -s orchestrator"
fi

if [ "$missing" = "1" ]; then
    note ""
    note "Not usable yet: herdr is missing. The links are in place; install herdr and run ./install.sh --check."
    exit 1
fi
