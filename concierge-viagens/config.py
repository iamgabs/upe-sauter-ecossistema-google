"""Configurações da aplicação web (lidas de variáveis de ambiente / .env)."""
import os
from pathlib import Path

from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent
load_dotenv(BASE_DIR / ".env")

HOST = os.getenv("HOST", "127.0.0.1")
PORT = int(os.getenv("PORT", "8000"))

# Nome da aplicação para o ADK: agrupa as sessões deste projeto.
ADK_APP_NAME = "concierge-viagens"

# Limites e tempos
MAX_MESSAGE_CHARS = 1000
AGENT_TIMEOUT_SECONDS = 90

# Onde o log de interações é gravado (uma linha JSON por interação).
LOG_DIR = BASE_DIR / "logs"
INTERACTION_LOG_FILE = LOG_DIR / "interactions.jsonl"

STATIC_DIR = BASE_DIR / "static"
