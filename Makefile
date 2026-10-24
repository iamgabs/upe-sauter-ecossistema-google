# @iamgabs "Gabriel Carvalho"
# ==============================================================================
# Setup do ambiente para os tutoriais de agentes com Google ADK
#
#   make setup   -> verifica/instala uv + Python e instala o google-adk no .venv
#   make check   -> apenas verifica o que ja esta instalado (nao instala nada)
#   make clean   -> remove o ambiente virtual (.venv)
#
# Funciona em macOS, Linux, WSL e Windows (PowerShell, cmd ou Git Bash).
# Sem o `make`? Rode `sh bootstrap.sh` (macOS/Linux) ou `bootstrap.cmd` (Windows):
# ele instala o make e executa o setup.
# ==============================================================================

# Versao do Python usada nos tutoriais e pasta do ambiente virtual.
# Podem ser sobrescritas:  make setup PYTHON_VERSION=3.13
PYTHON_VERSION ?= 3.12
VENV           ?= .venv

export PYTHON_VERSION
export VENV

# Escolhe o script de acordo com o sistema operacional.
ifeq ($(OS),Windows_NT)
  RUN := powershell -NoProfile -ExecutionPolicy Bypass -File scripts/setup.ps1
else
  RUN := sh scripts/setup.sh
endif

.DEFAULT_GOAL := help
.PHONY: help setup check clean uv python venv adk

help: ## Mostra esta ajuda
	@echo "Gabriel Carvalho"
	@echo "Comandos disponiveis:"
	@echo "  make setup    Verifica e instala uv, Python $(PYTHON_VERSION) e google-adk (em $(VENV))"
	@echo "  make check    Apenas verifica o que ja esta instalado"
	@echo "  make clean    Remove o ambiente virtual ($(VENV))"
	@echo ""
	@echo "Passos individuais: make uv | make python | make venv | make adk"
	@echo ""
	@echo "Depois do setup, ative o ambiente:"
	@echo "  macOS/Linux : source $(VENV)/bin/activate"
	@echo "  Windows     : $(VENV)/Scripts/Activate.ps1   (PowerShell)"
	@echo ""
	@echo "Ainda nao tem o make? Use o bootstrap (ele instala o make e roda o setup):"
	@echo "  macOS/Linux : sh bootstrap.sh"
	@echo "  Windows     : bootstrap.cmd"

setup: ## Executa todos os passos
	@$(RUN) all

check: ## Somente verifica
	@$(RUN) check

uv:
	@$(RUN) uv

python:
	@$(RUN) python

venv:
	@$(RUN) venv

adk:
	@$(RUN) adk

clean: ## Remove o ambiente virtual
	@$(RUN) clean
