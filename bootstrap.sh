#!/bin/sh
# Ponto de entrada para macOS / Linux / WSL / Git Bash.
#
#   sh bootstrap.sh            -> instala o `make` (se faltar) e roda `make setup`
#   sh bootstrap.sh check      -> idem, mas roda `make check` (ou clean, help, ...)
#
# Se não for possível instalar o `make`, o setup roda direto pelos scripts
# (scripts/setup.sh), então o aluno nunca fica travado.

set -eu
cd "$(dirname "$0")"

# No Git Bash/MSYS/Cygwin o caminho certo é o PowerShell.
case "$(uname -s 2>/dev/null || echo unknown)" in
  MINGW*|MSYS*|CYGWIN*)
    exec powershell -NoProfile -ExecutionPolicy Bypass -File bootstrap.ps1 "$@"
    ;;
esac

TARGET="${1:-setup}"

# ---------- estilo (igual ao scripts/setup.sh) -------------------------------
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  esc="$(printf '\033')"
  BOLD="${esc}[1m"; DIM="${esc}[2m"; RED="${esc}[31m"; GREEN="${esc}[32m"
  YELLOW="${esc}[33m"; CYAN="${esc}[36m"; MAGENTA="${esc}[35m"; RESET="${esc}[0m"
else
  BOLD=""; DIM=""; RED=""; GREEN=""; YELLOW=""; CYAN=""; MAGENTA=""; RESET=""
fi
case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in
  *[Uu][Tt][Ff]-8*|*[Uu][Tt][Ff]8*) I_OK="✔"; I_ERR="✖"; I_WARN="▲"; I_RUN="…"; I_DOT="◆" ;;
  *)                                I_OK="v"; I_ERR="x"; I_WARN="!"; I_RUN="..."; I_DOT="*" ;;
esac

ok()   { printf '  %s%s%s %s' "$GREEN" "$I_OK" "$RESET" "$1"
         [ -n "${2:-}" ] && printf '  %s%s%s' "$DIM" "$2" "$RESET"; printf '\n'; }
info() { printf '  %s%s %s%s\n' "$DIM" "$I_RUN" "$*" "$RESET"; }
warn() { printf '  %s%s%s %s\n' "$YELLOW" "$I_WARN" "$RESET" "$*"; }
has()  { command -v "$1" >/dev/null 2>&1; }

# ---------- localizar / instalar o make --------------------------------------
OS="$(uname -s 2>/dev/null || echo unknown)"
MAKE_CMD=""

find_make() {
  for c in make gmake; do
    has "$c" || continue
    # No macOS, /usr/bin/make é só um atalho que abre o instalador das
    # Command Line Tools; só vale se elas estiverem de fato instaladas.
    if [ "$OS" = "Darwin" ] && [ "$c" = "make" ]; then
      xcode-select -p >/dev/null 2>&1 || continue
    fi
    if "$c" --version >/dev/null 2>&1; then MAKE_CMD="$c"; return 0; fi
  done
  return 1
}

as_root() {
  if [ "$(id -u)" -eq 0 ]; then "$@"
  elif has sudo; then sudo "$@"
  else return 1
  fi
}

install_make() {
  case "$OS" in
    Darwin)
      if has brew; then
        info "Instalando make via Homebrew"
        brew install make
      else
        info "Instalando as Command Line Tools da Apple (abre uma janela, confirme a instalação)"
        xcode-select --install 2>/dev/null || true
        return 1
      fi
      ;;
    Linux)
      if   has apt-get; then as_root apt-get update -qq && as_root apt-get install -y make
      elif has dnf;     then as_root dnf install -y make
      elif has yum;     then as_root yum install -y make
      elif has pacman;  then as_root pacman -S --noconfirm make
      elif has zypper;  then as_root zypper --non-interactive install make
      elif has apk;     then as_root apk add make
      else return 1
      fi
      ;;
    *) return 1 ;;
  esac
}

# ---------- main -------------------------------------------------------------
printf '\n%s%s %sGoogle ADK%s %s· bootstrap%s\n\n' "$MAGENTA" "$I_DOT" "$BOLD" "$RESET" "$DIM" "$RESET"

if find_make; then
  ok "make já instalado" "$MAKE_CMD"
else
  info "make não encontrado, tentando instalar"
  if install_make && find_make; then
    ok "make instalado" "$MAKE_CMD"
  else
    printf '  %s%s%s Não consegui instalar o make automaticamente.\n' "$YELLOW" "$I_WARN" "$RESET"
    printf '  %sSem problema: vou rodar o setup direto pelos scripts.%s\n' "$DIM" "$RESET"
    MAKE_CMD=""
  fi
fi

echo
if [ -n "$MAKE_CMD" ]; then
  exec "$MAKE_CMD" "$TARGET"
fi

# Fallback sem make: mapeia o alvo do Makefile para o comando do script.
case "$TARGET" in
  setup) TARGET=all ;;
  help)  TARGET=check ;;
esac
exec sh scripts/setup.sh "$TARGET"
