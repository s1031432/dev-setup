#!/usr/bin/env bash
# =========================================
# Dev Environment Setup Script
# macOS / Linux — Enhanced Terminal UI
#
# Each package gets its own progress bar
# that animates 0% → 100%.
#
# Layout during install:
#   ⚡  zsh              already installed   ← committed (scrolled up)
#   ⚡  git              already installed   ← committed
#   ⣾  Installing fzf   3s                  ← Line A: live status
#   [████████░░░░░░░░░░░░░░░░░░] 30%        ← Line B: live bar (bottom)
#
# Two-line block (A + B) is always at the
# bottom. Everything above is permanent.
# =========================================

set -e

# ────────────────────────────────────────────
# ANSI
# ────────────────────────────────────────────
RESET=$'\033[0m'
BOLD=$'\033[1m'
DIM=$'\033[2m'

FG_WHITE=$'\033[97m'
FG_CYAN=$'\033[96m'
FG_GREEN=$'\033[92m'
FG_YELLOW=$'\033[93m'
FG_BLUE=$'\033[94m'
FG_MAGENTA=$'\033[95m'
FG_RED=$'\033[91m'
FG_GRAY=$'\033[90m'

BG_DARK=$'\033[48;5;234m'

CL=$'\033[2K'
HIDE=$'\033[?25l'
SHOW=$'\033[?25h'
CUR_UP=$'\033[1A'

cleanup() { printf '%s\n' "$SHOW"; }
trap cleanup EXIT INT TERM

# ────────────────────────────────────────────
# Banner
# ────────────────────────────────────────────
print_banner() {
  echo
  printf '%s%s' "$BOLD" "$FG_CYAN"
  cat << 'BANNER'
  ██████╗ ███████╗██╗   ██╗    ███████╗███████╗████████╗██╗   ██╗██████╗ 
  ██╔══██╗██╔════╝██║   ██║    ██╔════╝██╔════╝╚══██╔══╝██║   ██║██╔══██╗
  ██║  ██║█████╗  ██║   ██║    ███████╗█████╗     ██║   ██║   ██║██████╔╝
  ██║  ██║██╔══╝  ╚██╗ ██╔╝    ╚════██║██╔══╝     ██║   ██║   ██║██╔═══╝ 
  ██████╔╝███████╗ ╚████╔╝     ███████║███████╗   ██║   ╚██████╔╝██║     
  ╚═════╝ ╚══════╝  ╚═══╝      ╚══════╝╚══════╝   ╚═╝    ╚═════╝ ╚═╝     
BANNER
  printf '%s\n' "$RESET"
  echo -e "  ${FG_GRAY}${DIM}Auto-configure your perfect development environment${RESET}"
  echo -e "  ${FG_GRAY}${DIM}──────────────────────────────────────────────────${RESET}"
  echo
}

# ────────────────────────────────────────────
# Spinner (standalone — for non-bar sections)
#   Waits for $!, prints result + \n
# ────────────────────────────────────────────
SPINNER_FRAMES=("⣾" "⣽" "⣻" "⢿" "⡿" "⣟" "⣯" "⣷")

spinner_ln() {
  local pid=$!
  local label="$1"
  local timeout="${2:-0}"
  local frame=0
  local start=$SECONDS

  printf '%s' "$HIDE"

  while kill -0 "$pid" 2>/dev/null; do
    local elapsed=$(( SECONDS - start ))
    local f="${SPINNER_FRAMES[$((frame % ${#SPINNER_FRAMES[@]}))]}"
    printf "\r${CL}  ${FG_CYAN}%s${RESET}  ${FG_WHITE}%-28s${RESET} ${FG_GRAY}${DIM}%ds${RESET}" \
      "$f" "$label" "$elapsed"
    frame=$(( frame + 1 ))

    if [ "$timeout" -gt 0 ] && [ "$elapsed" -ge "$timeout" ]; then
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
      printf "\r${CL}  ${FG_YELLOW}⚠${RESET}  ${FG_WHITE}%-28s${RESET} ${FG_GRAY}${DIM}timed out${RESET}\n" "$label"
      printf '%s' "$SHOW"; return 1
    fi
    sleep 0.08
  done

  wait "$pid" 2>/dev/null
  local rc=$?
  if [ "$rc" -eq 0 ]; then
    printf "\r${CL}  ${FG_GREEN}✔${RESET}  ${FG_WHITE}%-28s${RESET} ${FG_GRAY}${DIM}done${RESET}\n" "$label"
  else
    printf "\r${CL}  ${FG_RED}✖${RESET}  ${FG_WHITE}%-28s${RESET} ${FG_GRAY}${DIM}failed${RESET}\n" "$label"
  fi
  printf '%s' "$SHOW"; return "$rc"
}

# ────────────────────────────────────────────
# Progress bar renderer
#
#   Muted gradient: indigo → steel → teal → sage
#   Draws at current cursor position, NO \n.
# ────────────────────────────────────────────
BAR_COLORS=(
  $'\033[38;5;60m'    # muted indigo
  $'\033[38;5;67m'    # steel blue
  $'\033[38;5;73m'    # cadet blue
  $'\033[38;5;79m'    # aquamarine
  $'\033[38;5;80m'    # muted cyan
  $'\033[38;5;115m'   # dark sea green
  $'\033[38;5;114m'   # spring green
  $'\033[38;5;151m'   # pale sage
)

draw_bar_pct() {
  local pct=$1
  (( pct > 100 )) && pct=100
  (( pct < 0 ))   && pct=0

  local bw=36
  local filled=$(( pct * bw / 100 ))
  local empty=$(( bw - filled ))
  local nc=${#BAR_COLORS[@]}

  local bar_f="" bar_e=""
  for (( i=0; i<filled; i++ )); do
    bar_f+="${BAR_COLORS[$(( i * nc / bw ))]}█${RESET}"
  done
  for (( i=0; i<empty; i++ )); do
    bar_e+="${FG_GRAY}${DIM}░${RESET}"
  done

  local pc=$'\033[38;5;67m'
  (( pct >= 50 )) && pc=$'\033[38;5;73m'
  (( pct >= 90 )) && pc=$'\033[38;5;114m'

  printf "\r${CL}  ${FG_GRAY}[${RESET}%s%s${FG_GRAY}]${RESET}  ${BOLD}%s%3d%%${RESET}" \
    "$bar_f" "$bar_e" "$pc" "$pct"
}

# ────────────────────────────────────────────
# Two-line animation block
#
#   Line A (status) + Line B (bar) always at
#   the bottom of visible output.
#
#   Cursor dance per frame:
#     \r[CL] print status     ← update Line A
#     \n                      ← move to Line B
#     \r[CL] draw bar         ← update Line B
#     \033[1A\r               ← back to Line A
#
#   When done:
#     print final status\n    ← commit Line A
#     \r[CL]                  ← clear Line B
#     → cursor is on empty line = next Line A
# ────────────────────────────────────────────

# Draw one frame: status on Line A, bar on Line B
draw_frame() {
  local status_text="$1"
  local pct=$2

  printf "\r${CL}%s" "$status_text"     # Line A
  printf "\n"                            # → Line B
  draw_bar_pct "$pct"                    # Line B (no \n)
  printf "${CUR_UP}\r"                   # ← back to Line A
}

# Commit: finalize status, clear bar, cursor ready for next
commit_frame() {
  local final_status="$1"

  printf "\r${CL}%s\n" "$final_status"  # commit Line A
  printf "\r${CL}"                       # clear Line B (bar gone)
  # cursor is now on empty line = next Line A
}

# ────────────────────────────────────────────
# Install a package with per-pkg progress bar
# ────────────────────────────────────────────
skipped_pkgs=()
done_pkgs=()
failed_pkgs=()

install_pkg() {
  local pkg=$1

  printf '%s' "$HIDE"

  if ! command -v "$pkg" >/dev/null 2>&1; then
    # ── Needs install: animated bar + spinner ──
    ( $PKG_INSTALL "$pkg" >/dev/null 2>&1 ) &
    local pid=$!
    local frame=0
    local start=$SECONDS

    while kill -0 "$pid" 2>/dev/null; do
      local elapsed=$(( SECONDS - start ))
      local f="${SPINNER_FRAMES[$((frame % ${#SPINNER_FRAMES[@]}))]}"

      # Simulated progress: asymptotic approach to 90%
      #   0s→0%  2s→18%  5s→36%  10s→50%  20s→64%  40s→75%  never >90%
      local pct=$(( 90 * elapsed / (elapsed + 8) ))

      local status
      status="$(printf "  ${FG_CYAN}%s${RESET}  ${FG_WHITE}%-28s${RESET} ${FG_GRAY}${DIM}%ds${RESET}" \
        "$f" "Installing $pkg" "$elapsed")"

      draw_frame "$status" "$pct"

      frame=$(( frame + 1 ))
      sleep 0.08
    done

    wait "$pid" 2>/dev/null
    local rc=$?

    if [ "$rc" -eq 0 ]; then
      # Animate 90% → 100%
      for p in 92 95 98 100; do
        local status
        status="$(printf "  ${FG_GREEN}✔${RESET}  ${FG_WHITE}%-28s${RESET} ${FG_GRAY}${DIM}done${RESET}" "$pkg")"
        draw_frame "$status" "$p"
        sleep 0.03
      done
      sleep 0.1

      commit_frame "$(printf "  ${FG_GREEN}✔${RESET}  ${FG_WHITE}%-28s${RESET} ${FG_GRAY}${DIM}done${RESET}" "$pkg")"
      done_pkgs+=("$pkg")
    else
      draw_frame "$(printf "  ${FG_RED}✖${RESET}  ${FG_WHITE}%-28s${RESET} ${FG_GRAY}${DIM}failed${RESET}" "$pkg")" 100
      sleep 0.15
      commit_frame "$(printf "  ${FG_RED}✖${RESET}  ${FG_WHITE}%-28s${RESET} ${FG_GRAY}${DIM}failed${RESET}" "$pkg")"
      failed_pkgs+=("$pkg")
    fi

  else
    # ── Already installed: quick sweep 0→100% ──
    local steps=(0 12 28 45 65 82 100)
    for p in "${steps[@]}"; do
      local status
      status="$(printf "  ${FG_YELLOW}⚡${RESET}  ${FG_WHITE}%-28s${RESET} ${FG_GRAY}${DIM}already installed${RESET}" "$pkg")"
      draw_frame "$status" "$p"
      sleep 0.035
    done
    sleep 0.08

    commit_frame "$(printf "  ${FG_YELLOW}⚡${RESET}  ${FG_WHITE}%-28s${RESET} ${FG_GRAY}${DIM}already installed${RESET}" "$pkg")"
    skipped_pkgs+=("$pkg")
  fi

  printf '%s' "$SHOW"
}

# ────────────────────────────────────────────
# Section / step helpers
# ────────────────────────────────────────────
print_section() {
  echo
  echo -e "  ${BOLD}${FG_MAGENTA}◈  $1${RESET}"
  echo -e "  ${FG_GRAY}${DIM}$(printf '─%.0s' {1..44})${RESET}"
}

print_step() {
  echo -e "  ${FG_BLUE}→${RESET}  ${FG_WHITE}$1${RESET}"
}

# ────────────────────────────────────────────
# Summary
# ────────────────────────────────────────────
print_summary() {
  echo
  echo -e "  ${BG_DARK}${BOLD}${FG_CYAN}  ┌─────────────────────────────────────────┐  ${RESET}"
  echo -e "  ${BG_DARK}${BOLD}${FG_CYAN}  │         Setup Complete  🎉              │  ${RESET}"
  echo -e "  ${BG_DARK}${BOLD}${FG_CYAN}  └─────────────────────────────────────────┘  ${RESET}"
  echo

  if [ ${#done_pkgs[@]} -gt 0 ]; then
    echo -e "  ${FG_GREEN}${BOLD}Installed (${#done_pkgs[@]})${RESET}"
    for p in "${done_pkgs[@]}"; do
      echo -e "    ${FG_GREEN}✔${RESET}  $p"
    done
  fi

  if [ ${#skipped_pkgs[@]} -gt 0 ]; then
    echo
    echo -e "  ${FG_YELLOW}${BOLD}Already present (${#skipped_pkgs[@]})${RESET}"
    for p in "${skipped_pkgs[@]}"; do
      echo -e "    ${FG_YELLOW}⚡${RESET}  $p"
    done
  fi

  if [ ${#failed_pkgs[@]} -gt 0 ]; then
    echo
    echo -e "  ${FG_RED}${BOLD}Failed (${#failed_pkgs[@]})${RESET}"
    for p in "${failed_pkgs[@]}"; do
      echo -e "    ${FG_RED}✖${RESET}  $p"
    done
  fi

  echo
  echo -e "  ${FG_GRAY}${DIM}Restart your terminal or run:${RESET}"
  echo -e "  ${BOLD}${FG_CYAN}  source ~/.zshrc${RESET}"
  echo
}

# ════════════════════════════════════════════
# MAIN
# ════════════════════════════════════════════

print_banner

# ── OS Detection ───────────────────────────
print_section "Detecting Environment"

OS=""
if [[ "$OSTYPE" == "darwin"* ]]; then
  OS="macos"
elif [[ -f /etc/os-release ]]; then
  OS="linux"
else
  echo -e "  ${FG_RED}✖${RESET}  Unsupported OS: $OSTYPE"
  exit 1
fi

echo -e "  ${FG_GREEN}✔${RESET}  OS detected: ${BOLD}${FG_WHITE}$OS${RESET}"

# ── Package Manager ─────────────────────────
print_section "Package Manager"

PKG_INSTALL=""

if [ "$OS" == "macos" ]; then
  if ! command -v brew >/dev/null 2>&1; then
    print_step "Installing Homebrew"
    (
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" >/dev/null 2>&1
    ) &
    spinner_ln "Homebrew" 300 || true
    done_pkgs+=("homebrew")
  else
    echo -e "  ${FG_YELLOW}⚡${RESET}  Homebrew already installed"
  fi

  ( brew update >/dev/null 2>&1 ) &
  spinner_ln "brew update" 60 || {
    echo -e "  ${FG_GRAY}${DIM}  → timed out, continuing${RESET}"
  }

  PKG_INSTALL="brew install"

elif [ "$OS" == "linux" ]; then
  if command -v apt >/dev/null 2>&1; then
    PKG_INSTALL="sudo apt install -y"
    ( sudo apt update -y >/dev/null 2>&1 ) &
    spinner_ln "apt update" 60 || true
  elif command -v dnf >/dev/null 2>&1; then
    PKG_INSTALL="sudo dnf install -y"
  elif command -v yum >/dev/null 2>&1; then
    PKG_INSTALL="sudo yum install -y"
  elif command -v pacman >/dev/null 2>&1; then
    PKG_INSTALL="sudo pacman -S --noconfirm"
    ( sudo pacman -Sy >/dev/null 2>&1 ) &
    spinner_ln "pacman sync" 60 || true
  elif command -v zypper >/dev/null 2>&1; then
    PKG_INSTALL="sudo zypper install -y"
  else
    echo -e "  ${FG_RED}✖${RESET}  No supported package manager found"
    exit 1
  fi
  echo -e "  ${FG_GREEN}✔${RESET}  Package manager ready"
fi

# ── Packages ────────────────────────────────
pkgs=(zsh git curl fzf zoxide delta tig bat tree ripgrep jq httpie tmux neovim gh neofetch cowsay fd lazygit duf ncdu)
total=${#pkgs[@]}

print_section "Installing Packages (${total} total)"

for pkg in "${pkgs[@]}"; do
  install_pkg "$pkg"
done

echo -e "  ${FG_GREEN}${BOLD}✔  All $total packages processed${RESET}"

# ── exa / eza ───────────────────────────────
print_section "Modern ls Replacement"

if ! command -v exa >/dev/null 2>&1 && ! command -v eza >/dev/null 2>&1; then
  if [ "$OS" == "macos" ]; then
    ( brew install eza >/dev/null 2>&1 ) &
  else
    ( $PKG_INSTALL eza >/dev/null 2>&1 ) &
  fi
  spinner_ln "Installing eza" 120 || true
  done_pkgs+=("eza")
  grep -q 'alias exa=' ~/.zshrc 2>/dev/null || {
    echo 'alias exa="eza"' >> ~/.zshrc
    echo -e "  ${FG_GRAY}${DIM}  → aliased exa → eza in .zshrc${RESET}"
  }
else
  echo -e "  ${FG_YELLOW}⚡${RESET}  exa/eza already available"
fi

# ── nvm ─────────────────────────────────────
print_section "Node Version Manager (nvm)"

export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

if [ ! -d "$NVM_DIR" ]; then
  print_step "Installing nvm"
  (
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash >/dev/null 2>&1
  ) &
  spinner_ln "nvm" 120 || true
  done_pkgs+=("nvm")

  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

  if command -v nvm >/dev/null 2>&1; then
    print_step "Installing Node.js LTS"
    ( nvm install --lts >/dev/null 2>&1 ) &
    spinner_ln "Node.js LTS" 180 || true
    done_pkgs+=("node-lts")
  fi
else
  echo -e "  ${FG_YELLOW}⚡${RESET}  nvm already installed"
  skipped_pkgs+=("nvm")

  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
  if command -v node >/dev/null 2>&1; then
    local_node=$(node --version 2>/dev/null || echo "?")
    echo -e "  ${FG_GRAY}${DIM}  → Node.js ${local_node} detected${RESET}"
  fi
fi

# ── Oh My Zsh ───────────────────────────────
print_section "Oh My Zsh"

if [ ! -d "$HOME/.oh-my-zsh" ]; then
  print_step "Installing Oh My Zsh"
  (
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended >/dev/null 2>&1
  ) &
  spinner_ln "Oh My Zsh" 120 || true
  done_pkgs+=("oh-my-zsh")
else
  echo -e "  ${FG_YELLOW}⚡${RESET}  Oh My Zsh already installed"
  skipped_pkgs+=("oh-my-zsh")
fi

# ── Powerlevel10k ────────────────────────────
print_section "Powerlevel10k Theme"

P10K_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
if [ ! -d "$P10K_DIR" ]; then
  (
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR" >/dev/null 2>&1
  ) &
  spinner_ln "powerlevel10k" 60 || true
  done_pkgs+=("powerlevel10k")
else
  echo -e "  ${FG_YELLOW}⚡${RESET}  Powerlevel10k already installed"
  skipped_pkgs+=("powerlevel10k")
fi

# ── Zsh Plugins ──────────────────────────────
print_section "Zsh Plugins"

for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
  plugin_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/$plugin"
  if [ ! -d "$plugin_dir" ]; then
    (
      git clone "https://github.com/zsh-users/$plugin" "$plugin_dir" >/dev/null 2>&1
    ) &
    spinner_ln "$plugin" 60 || true
    done_pkgs+=("$plugin")
  else
    echo -e "  ${FG_YELLOW}⚡${RESET}  $plugin already installed"
    skipped_pkgs+=("$plugin")
  fi
done

# ── .zshrc Configuration ─────────────────────
print_section "Configuring .zshrc"

ZSHRC="$HOME/.zshrc"
touch "$ZSHRC"

if [ ! -f "$ZSHRC.bak-devsetup" ]; then
  cp "$ZSHRC" "$ZSHRC.bak-devsetup"
  echo -e "  ${FG_GRAY}${DIM}  → backed up .zshrc → .zshrc.bak-devsetup${RESET}"
fi

apply_zshrc() {
  local label="$1" check="$2" action="$3"
  if ! grep -qF "$check" "$ZSHRC" 2>/dev/null; then
    eval "$action"
    echo -e "  ${FG_GREEN}✔${RESET}  $label"
  else
    echo -e "  ${FG_GRAY}${DIM}  ─  $label (already set)${RESET}"
  fi
}

apply_zshrc "Powerlevel10k theme" \
  'powerlevel10k/powerlevel10k' \
  "sed -i.bak 's/^ZSH_THEME=.*/ZSH_THEME=\"powerlevel10k\/powerlevel10k\"/' \"\$ZSHRC\" || echo 'ZSH_THEME=\"powerlevel10k/powerlevel10k\"' >> \"\$ZSHRC\""

for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
  apply_zshrc "Plugin: $plugin" \
    "$plugin" \
    "sed -i.bak \"s/^plugins=(/plugins=($plugin /\" \"\$ZSHRC\" || echo \"plugins=($plugin)\" >> \"\$ZSHRC\""
done

apply_zshrc "fzf source" \
  '.fzf.zsh' \
  "echo '[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh' >> \"\$ZSHRC\""

apply_zshrc "zoxide init" \
  'zoxide init zsh' \
  "echo 'eval \"\$(zoxide init zsh)\"' >> \"\$ZSHRC\""

apply_zshrc "alias j=z" \
  'alias j=' \
  "echo 'alias j=\"z -i\"' >> \"\$ZSHRC\""

apply_zshrc "nvm loader" \
  'NVM_DIR' \
  "cat >> \"\$ZSHRC\" << 'NVMEOF'

# nvm
export NVM_DIR=\"\$HOME/.nvm\"
[ -s \"\$NVM_DIR/nvm.sh\" ] && . \"\$NVM_DIR/nvm.sh\"
[ -s \"\$NVM_DIR/bash_completion\" ] && . \"\$NVM_DIR/bash_completion\"
NVMEOF"

apply_zshrc "cowsay + neofetch greeting" \
  'neofetch' \
  "cat >> \"\$ZSHRC\" << 'EOF'

# Greeting on interactive shells
if [[ \$- == *i* ]]; then
  command -v cowsay  >/dev/null 2>&1 && echo \"Welcome!\" | cowsay -f sheep
  command -v neofetch >/dev/null 2>&1 && neofetch
fi
EOF"

# ── Default Shell ────────────────────────────
print_section "Default Shell"

ZSH_PATH="$(command -v zsh 2>/dev/null || echo /bin/zsh)"
if [ "$SHELL" != "$ZSH_PATH" ]; then
  print_step "Changing default shell to zsh"
  if chsh -s "$ZSH_PATH" 2>/dev/null; then
    echo -e "  ${FG_GREEN}✔${RESET}  Default shell → zsh"
  else
    echo -e "  ${FG_YELLOW}⚠${RESET}  Auto-change failed. Run manually:"
    echo -e "     ${BOLD}chsh -s $ZSH_PATH${RESET}"
  fi
else
  echo -e "  ${FG_YELLOW}⚡${RESET}  zsh is already your default shell"
fi

# ── Done ─────────────────────────────────────
print_summary
