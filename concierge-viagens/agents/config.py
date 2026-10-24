"""Configuração compartilhada pelos agentes.

Fica dentro do pacote `agents` para que ele seja autossuficiente: funciona tanto
quando importado pela API (FastAPI) quanto quando aberto pelo `adk web`.
"""
import os
from pathlib import Path

from dotenv import load_dotenv

# Carrega o .env da raiz do projeto (idempotente: não sobrescreve variáveis já definidas).
PROJECT_ROOT = Path(__file__).resolve().parents[1]
load_dotenv(PROJECT_ROOT / ".env")

# Modelo usado por TODOS os agentes. Trocar aqui (ou via variável MODEL) muda o projeto inteiro.
MODEL = os.getenv("MODEL", "gemini-2.5-flash")

# Base de dados fictícia usada pela ferramenta de destinos.
DESTINOS_FILE = PROJECT_ROOT / "data" / "destinos.json"
