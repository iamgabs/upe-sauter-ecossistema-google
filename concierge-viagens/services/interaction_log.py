"""Registro (log) das interações com o agente.

Cada atendimento vira uma linha JSON em `logs/interactions.jsonl`. Esse histórico é o
que permite auditar, medir qualidade e depurar o agente depois. Num sistema maior,
o destino costuma ser um data warehouse; a ideia é a mesma.

O registro é "dispare e esqueça": roda em segundo plano para não atrasar a resposta.
"""
import asyncio
import json
import logging
from datetime import datetime, timezone

from config import INTERACTION_LOG_FILE, LOG_DIR

logger = logging.getLogger(__name__)

# O asyncio só guarda referência fraca das tarefas; guardamos as nossas até terminarem.
_pending: set[asyncio.Task] = set()


def _write(entry: dict) -> None:
    try:
        LOG_DIR.mkdir(parents=True, exist_ok=True)
        with INTERACTION_LOG_FILE.open("a", encoding="utf-8") as fh:
            fh.write(json.dumps(entry, ensure_ascii=False) + "\n")
    except OSError as exc:
        logger.error("Falha ao gravar log de interação: %s", exc)


def log_interaction(**fields) -> None:
    """Agenda a gravação de uma interação sem bloquear quem chamou."""
    entry = {"timestamp": datetime.now(timezone.utc).isoformat(), **fields}
    task = asyncio.create_task(asyncio.to_thread(_write, entry))
    _pending.add(task)
    task.add_done_callback(_pending.discard)
