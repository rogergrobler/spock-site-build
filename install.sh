#!/usr/bin/env bash
# Spock Beta 0.1 — partner install.
#
# The bar (charter §5): a partner pastes ONE command and the machine does the rest —
# checks its own prerequisites, fixes what it safely can, speaks plain English, and
# ends with a green "Spock is ready" or a single red line to send Roger. No partner
# ever types a second terminal command; after this they just talk to Spock.
#
# ── For a partner ──
#   Roger sends you a one-line command with your token already in it. Paste it. Done.
#
# ── For Roger (make a partner's one-paste command) ──
#   packs/listed-eq/ops/install-partner.sh --bundle "<TOKEN>" [--url URL] [--deepseek KEY] [--openai KEY] [--gemini KEY]
#   → prints the exact command to send that partner.
#
# ── How it runs ──
#   Reads its inputs from environment variables (so the one-paste command carries them):
#     SPOCK_API_TOKEN   (required)   your partner token
#     SPOCK_API_URL     (optional)   the server address (default below)
#     DEEPSEEK_API_KEY / OPENAI_API_KEY / GEMINI_API_KEY (optional)
#   With no SPOCK_API_TOKEN and a terminal attached, it asks for the token interactively.

set -euo pipefail

REPO_URL="${SPOCK_REPO_URL:-https://github.com/rogergrobler/spock.git}"
INSTALL_DIR="${SPOCK_INSTALL_DIR:-$HOME/code/spock}"
CONFIG_PATH="$HOME/.spock/config"
DEFAULT_URL="${SPOCK_API_URL:-http://spock-vps:8000}"

say()  { printf '%s\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
bad()  { printf '  \033[31m✗\033[0m %s\n' "$*"; }
die()  { printf '\n\033[31mStopped: %s\033[0m\n\nSend Roger this line: %s\n' "$1" "${2:-$1}"; exit 1; }

# ── Roger's bundle generator ────────────────────────────────────────────────
if [ "${1:-}" = "--bundle" ]; then
  TOK="${2:?usage: install-partner.sh --bundle <TOKEN> [--url URL] [--deepseek KEY] ...}"
  shift 2
  URL="$DEFAULT_URL"; DS=""; OA=""; GM=""
  while [ $# -gt 0 ]; do case "$1" in
    --url) URL="$2"; shift 2;; --deepseek) DS="$2"; shift 2;;
    --openai) OA="$2"; shift 2;; --gemini) GM="$2"; shift 2;; *) shift;; esac; done
  RAW="https://raw.githubusercontent.com/rogergrobler/spock/main/packs/listed-eq/ops/install-partner.sh"
  ENV="SPOCK_API_TOKEN='$TOK' SPOCK_API_URL='$URL'"
  [ -n "$DS" ] && ENV="$ENV DEEPSEEK_API_KEY='$DS'"
  [ -n "$OA" ] && ENV="$ENV OPENAI_API_KEY='$OA'"
  [ -n "$GM" ] && ENV="$ENV GEMINI_API_KEY='$GM'"
  say "Send this one line to the partner (it carries their token — treat as a secret):"
  say ""
  say "  $ENV bash <(curl -fsSL '$RAW')"
  say ""
  exit 0
fi

say "── Installing Spock (Beta 0.1) ──"
say ""

# ── 1. Prerequisites — check, and say plainly what to do if missing ─────────
say "Checking your machine…"
command -v git  >/dev/null 2>&1 && ok "git" || die "git is not installed" "Spock install: git is missing on my Mac"
if command -v python3 >/dev/null 2>&1; then
  PYV=$(python3 -c 'import sys;print("%d.%d"%sys.version_info[:2])' 2>/dev/null || echo 0.0)
  PYOK=$(python3 -c 'import sys;print(1 if sys.version_info[:2]>=(3,11) else 0)' 2>/dev/null || echo 0)
  [ "$PYOK" = "1" ] && ok "Python $PYV" || die "Python 3.11+ required (found $PYV)" "Spock install: my Python is $PYV, need 3.11+"
else
  die "Python 3 is not installed" "Spock install: Python 3 is missing on my Mac"
fi
if command -v claude >/dev/null 2>&1; then ok "Claude Code"; else
  bad "Claude Code not found — install it from claude.ai/code, then re-run this. (Spock will still install; you just can't run it until Claude Code is here.)"
fi

# ── 2. Get the repo ──────────────────────────────────────────────────────────
say ""
say "Getting Spock…"
if [ -d "$INSTALL_DIR/.git" ]; then
  git -C "$INSTALL_DIR" pull --ff-only -q && ok "updated $INSTALL_DIR" || die "could not update the existing copy at $INSTALL_DIR" "Spock install: git pull failed at $INSTALL_DIR"
else
  mkdir -p "$(dirname "$INSTALL_DIR")"
  git clone -q "$REPO_URL" "$INSTALL_DIR" && ok "downloaded to $INSTALL_DIR" || die "could not download Spock (is your GitHub access set up?)" "Spock install: git clone failed"
fi

# ── 3. Python environment + the spock command ───────────────────────────────
say ""
say "Setting up (this takes a minute)…"
PACK="$INSTALL_DIR/packs/listed-eq"
[ -d "$PACK/.venv" ] || python3 -m venv "$PACK/.venv"
"$PACK/.venv/bin/pip" install -q --upgrade pip >/dev/null 2>&1 || true
"$PACK/.venv/bin/pip" install -q -e "$PACK" >/dev/null 2>&1 && ok "installed the spock command" || die "could not install the Spock software" "Spock install: pip install -e failed"
mkdir -p "$HOME/bin"
ln -sf "$PACK/.venv/bin/spock" "$HOME/bin/spock"
case ":$PATH:" in *":$HOME/bin:"*) : ;; *)
  SHELLRC="$HOME/.zshrc"; [ -n "${BASH_VERSION:-}" ] && SHELLRC="$HOME/.bashrc"
  grep -q 'HOME/bin' "$SHELLRC" 2>/dev/null || printf '\nexport PATH="$HOME/bin:$PATH"\n' >> "$SHELLRC"
  export PATH="$HOME/bin:$PATH"
  ok "added the spock command to your PATH ($SHELLRC)"
esac

# ── 4. Configuration — from the one-paste env, or ask ───────────────────────
say ""
mkdir -p "$(dirname "$CONFIG_PATH")"; chmod 700 "$(dirname "$CONFIG_PATH")"
TOKEN="${SPOCK_API_TOKEN:-}"
if [ -z "$TOKEN" ]; then
  if [ -t 0 ]; then
    printf 'Paste your Spock token (from Roger; it will not show as you type): '
    stty -echo 2>/dev/null || true; read -r TOKEN; stty echo 2>/dev/null || true; printf '\n'
  fi
fi
[ -n "$TOKEN" ] || die "no token provided" "Spock install: I have no token — please resend my install command"
{
  echo "# Spock config — written by install-partner.sh"
  echo "SPOCK_API_URL=$DEFAULT_URL"
  echo "SPOCK_API_TOKEN=$TOKEN"
  [ -n "${DEEPSEEK_API_KEY:-}" ] && echo "DEEPSEEK_API_KEY=$DEEPSEEK_API_KEY"
  [ -n "${OPENAI_API_KEY:-}" ]   && echo "OPENAI_API_KEY=$OPENAI_API_KEY"
  [ -n "${GEMINI_API_KEY:-}" ]   && echo "GEMINI_API_KEY=$GEMINI_API_KEY"
} > "$CONFIG_PATH"
chmod 600 "$CONFIG_PATH"
ok "saved your settings to $CONFIG_PATH"

# ── 5. Prove it works ────────────────────────────────────────────────────────
say ""
say "── Checking everything is ready ──"
say ""
if "$PACK/.venv/bin/spock" doctor; then
  say ""
  say "You're set. To run a company, open Claude Code and type:  /spock-run <company name>"
else
  say ""
  say "Some checks did not pass (see the ✗ lines above). Screenshot this and send it to Roger."
  exit 1
fi
