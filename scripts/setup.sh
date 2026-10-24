#!/bin/sh
# Setup para macOS / Linux / WSL / Git Bash (POSIX sh).
# Uso: sh scripts/setup.sh [all|check|uv|python|venv|adk|clean]
#
# Cada passo é idempotente: só instala se ainda não estiver instalado.
# Cores podem ser desligadas com NO_COLOR=1.

set -eu

PYTHON_VERSION="${PYTHON_VERSION:-3.12}"
VENV="${VENV:-.venv}"

# ---------- estilo -----------------------------------------------------------
# Cores só quando a saída é um terminal e NO_COLOR não está definido.
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  esc="$(printf '\033')"
  BOLD="${esc}[1m"; DIM="${esc}[2m"; RED="${esc}[31m"; GREEN="${esc}[32m"
  YELLOW="${esc}[33m"; CYAN="${esc}[36m"; MAGENTA="${esc}[35m"; RESET="${esc}[0m"
else
  BOLD=""; DIM=""; RED=""; GREEN=""; YELLOW=""; CYAN=""; MAGENTA=""; RESET=""
fi

# Ícones Unicode só se o terminal for UTF-8; senão cai para ASCII.
case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in
  *[Uu][Tt][Ff]-8*|*[Uu][Tt][Ff]8*)
    I_OK="✔"; I_ERR="✖"; I_WARN="▲"; I_RUN="…"; I_ARROW="▸"; I_DOT="◆"; I_SEP="·" ;;
  *)
    I_OK="v"; I_ERR="x"; I_WARN="!"; I_RUN="..."; I_ARROW=">"; I_DOT="*"; I_SEP="-" ;;
esac

# ---------- helpers ----------------------------------------------------------
# ok "mensagem" ["detalhe em cinza"]
ok()   { printf '  %s%s%s %s' "$GREEN" "$I_OK" "$RESET" "$1"
         [ -n "${2:-}" ] && printf '  %s%s%s' "$DIM" "$2" "$RESET"; printf '\n'; }
info() { printf '  %s%s %s%s\n' "$DIM" "$I_RUN" "$*" "$RESET"; }
warn() { printf '  %s%s%s %s\n' "$YELLOW" "$I_WARN" "$RESET" "$*"; }
die()  { printf '  %s%s %s%s\n' "$RED" "$I_ERR" "$*" "$RESET" >&2; exit 1; }

# section "[1/4]" "Título"
section() { printf '\n%s%s%s %s%s%s\n' "$CYAN" "$1" "$RESET" "$BOLD" "$2" "$RESET"; }

has() { command -v "$1" >/dev/null 2>&1; }

# Executa um comando sem poluir a tela; se falhar, mostra a saída capturada.
quiet() {
  _log="$(mktemp)"
  if "$@" >"$_log" 2>&1; then
    rm -f "$_log"
  else
    printf '%s' "$DIM" >&2; cat "$_log" >&2; printf '%s' "$RESET" >&2
    rm -f "$_log"
    return 1
  fi
}

# Caminho do python dentro do venv (Git Bash/Windows usa Scripts/, o resto bin/)
venv_python() {
  if [ -x "$VENV/bin/python" ]; then
    echo "$VENV/bin/python"
  elif [ -f "$VENV/Scripts/python.exe" ]; then
    echo "$VENV/Scripts/python.exe"
  else
    echo ""
  fi
}

# Locais onde o instalador do uv coloca o binário (nem sempre já está no PATH)
add_uv_to_path() {
  PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
  export PATH
}

uv_version()  { uv --version | awk '{print $2}'; }
py_version()  { "$1" -c 'import platform; print(platform.python_version())'; }
# Roda fora do projeto para não "achar" o python do próprio .venv.
find_py()     { (cd "$HOME" && uv python find "$PYTHON_VERSION" 2>/dev/null); }
py_ok()       { has uv && find_py >/dev/null; }
venv_ok()     { _p="$(venv_python)"; [ -n "$_p" ] && "$_p" -c "import sys" >/dev/null 2>&1; }
adk_ok()      { has uv && uv pip show --python "$(venv_python)" google-adk >/dev/null 2>&1; }
adk_version() { uv pip show --python "$(venv_python)" google-adk 2>/dev/null | sed -n 's/^Version: //p'; }

banner() {
  printf '\n%s%s %sGoogle ADK%s %s%s%s setup do ambiente%s\n' \
    "$MAGENTA" "$I_DOT" "$BOLD" "$RESET" "$DIM" "$I_SEP" "$RESET" "$RESET"
  printf '  %sPython %s  %s  venv em %s%s\n' "$DIM" "$PYTHON_VERSION" "$I_SEP" "$VENV" "$RESET"
}

# ---------- passos -----------------------------------------------------------
step_uv() {
  add_uv_to_path
  if has uv; then
    ok "uv já instalado" "v$(uv_version)"
    return
  fi

  info "uv não encontrado, instalando"
  if has curl; then
    quiet sh -c 'curl -LsSf https://astral.sh/uv/install.sh | sh' \
      || die "Falha ao instalar o uv. Veja https://docs.astral.sh/uv/getting-started/installation/"
  elif has wget; then
    quiet sh -c 'wget -qO- https://astral.sh/uv/install.sh | sh' \
      || die "Falha ao instalar o uv. Veja https://docs.astral.sh/uv/getting-started/installation/"
  else
    die "Preciso de 'curl' ou 'wget' para instalar o uv. Instale um deles e rode 'make setup' de novo."
  fi

  add_uv_to_path
  has uv || die "uv instalado, mas não encontrado no PATH. Abra um novo terminal e rode 'make setup'."
  ok "uv instalado" "v$(uv_version)"
}

step_python() {
  has uv || step_uv
  if py_ok; then
    py="$(find_py)"
    ok "Python $PYTHON_VERSION já disponível" "$py"
    return
  fi

  info "Python $PYTHON_VERSION não encontrado, instalando via uv"
  quiet uv python install "$PYTHON_VERSION" || die "Falha ao instalar o Python $PYTHON_VERSION"
  ok "Python $PYTHON_VERSION instalado" "$(find_py)"
}

step_venv() {
  has uv || step_uv
  py_ok  || step_python

  if venv_ok; then
    ok "Ambiente virtual já existe" "$VENV"
    return
  fi

  if [ -d "$VENV" ]; then
    warn "$VENV existe mas está quebrado (ex.: criado em outro sistema), recriando"
    rm -rf "$VENV"
  fi
  info "Criando ambiente virtual"
  quiet uv venv "$VENV" --python "$PYTHON_VERSION" || die "Falha ao criar o ambiente virtual"
  ok "Ambiente virtual criado" "$VENV"
}

step_adk() {
  venv_ok || step_venv

  if adk_ok; then
    ok "google-adk já instalado" "v$(adk_version)"
    return
  fi

  info "Instalando google-adk (pode levar alguns segundos)"
  quiet uv pip install --python "$(venv_python)" google-adk || die "Falha ao instalar o google-adk"
  ok "google-adk instalado" "v$(adk_version)"
}

step_check() {
  add_uv_to_path
  missing=0
  printf '\n%s%s%s %sVerificando ambiente%s\n' "$MAGENTA" "$I_DOT" "$RESET" "$BOLD" "$RESET"
  echo

  if has uv; then ok "uv" "v$(uv_version)"
  else printf '  %s%s%s uv  %snão instalado%s\n' "$RED" "$I_ERR" "$RESET" "$DIM" "$RESET"; missing=1; fi

  if py_ok; then ok "Python $PYTHON_VERSION" "$(find_py)"
  else printf '  %s%s%s Python %s  %snão encontrado%s\n' "$RED" "$I_ERR" "$RESET" "$PYTHON_VERSION" "$DIM" "$RESET"; missing=1; fi

  if venv_ok; then
    ok "Ambiente virtual" "$VENV"
    if adk_ok; then ok "google-adk" "v$(adk_version)"
    else printf '  %s%s%s google-adk  %snão instalado em %s%s\n' "$RED" "$I_ERR" "$RESET" "$DIM" "$VENV" "$RESET"; missing=1; fi
  else
    printf '  %s%s%s Ambiente virtual  %s%s não existe%s\n' "$RED" "$I_ERR" "$RESET" "$DIM" "$VENV" "$RESET"; missing=1
  fi

  echo
  if [ "$missing" -ne 0 ]; then
    printf '  %sFaltam itens.%s Rode: %smake setup%s\n\n' "$YELLOW" "$RESET" "$BOLD" "$RESET"
    exit 1
  fi
  printf '  %s%s Tudo certo!%s\n\n' "$GREEN" "$I_OK" "$RESET"
}

step_clean() {
  printf '\n%s%s%s %sLimpando ambiente%s\n\n' "$MAGENTA" "$I_DOT" "$RESET" "$BOLD" "$RESET"
  if [ -d "$VENV" ]; then
    rm -rf "$VENV"
    ok "Removido" "$VENV"
  else
    ok "Nada para remover" "$VENV não existe"
  fi
  echo
}

step_all() {
  start="$(date +%s)"
  banner

  section "[1/4]" "uv";               step_uv
  section "[2/4]" "Python";           step_python
  section "[3/4]" "Ambiente virtual"; step_venv
  section "[4/4]" "google-adk";       step_adk

  elapsed=$(( $(date +%s) - start ))
  case "$(uname -s 2>/dev/null || echo unknown)" in
    MINGW*|MSYS*|CYGWIN*) activate="source $VENV/Scripts/activate" ;;
    *)                    activate="source $VENV/bin/activate" ;;
  esac

  printf '\n%s%s Ambiente pronto%s %s(%ss)%s\n\n' "$GREEN$BOLD" "$I_OK" "$RESET" "$DIM" "$elapsed" "$RESET"
  printf '  Ative o ambiente com:\n'
  printf '    %s%s%s\n\n' "$CYAN" "$activate" "$RESET"
}

# ---------- main -------------------------------------------------------------
case "${1:-all}" in
  all)    step_all ;;
  check)  step_check ;;
  uv)     section "$I_ARROW" "uv";               step_uv; echo ;;
  python) section "$I_ARROW" "Python";           step_python; echo ;;
  venv)   section "$I_ARROW" "Ambiente virtual"; step_venv; echo ;;
  adk)    section "$I_ARROW" "google-adk";       step_adk; echo ;;
  clean)  step_clean ;;
  *)      die "Comando desconhecido: $1 (use: all|check|uv|python|venv|adk|clean)" ;;
esac
