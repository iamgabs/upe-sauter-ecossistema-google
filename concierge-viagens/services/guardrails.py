"""Guardrails de entrada e de saída.

São as "grades de proteção" ao redor do agente: verificações que acontecem ANTES de a
mensagem chegar ao modelo e DEPOIS de a resposta sair dele. Aqui a implementação é
didática (regex simples) para dar para ler e entender em minutos. Em produção, o
ideal é combinar com serviços gerenciados de segurança de IA.

O que fazemos:
- entrada: rejeita mensagens vazias/longas, bloqueia tentativas óbvias de prompt injection
  e mascara dados sensíveis (CPF, cartão) antes de enviá-los ao modelo;
- saída: mascara dados sensíveis que o modelo possa ter devolvido.
"""
import re
from dataclasses import dataclass

from config import MAX_MESSAGE_CHARS

# Tentativas comuns de "sequestrar" o agente (PT e EN). Lista curta de propósito:
# não é uma defesa completa, é um exemplo do conceito.
_INJECTION_PATTERNS = [
    r"ignor(e|a|ar)\s+(todas?\s+)?(as\s+)?(suas\s+)?(instru[cç][õo]es|regras)",
    r"ignore\s+(all\s+)?(previous|prior|above)\s+instructions",
    r"(revele|mostre|exiba|repita)\s+(o\s+)?(seu\s+)?(system\s+prompt|prompt\s+do\s+sistema|prompt\s+inicial)",
    r"reveal\s+(your\s+)?(system\s+)?prompt",
    r"voc[eê]\s+agora\s+[eé]\s+(um|uma)\s+",
]
_INJECTION_RE = re.compile("|".join(_INJECTION_PATTERNS), re.IGNORECASE)

_CPF_RE = re.compile(r"\b\d{3}\.?\d{3}\.?\d{3}-?\d{2}\b")
_CARD_RE = re.compile(r"\b(?:\d[ -]?){13,16}\b")


@dataclass
class GuardResult:
    allowed: bool
    text: str  # texto já saneado (use este, não o original)
    reason: str = ""


def _mask_sensitive(text: str) -> str:
    text = _CPF_RE.sub("[CPF removido]", text)
    return _CARD_RE.sub("[cartão removido]", text)


def check_input(message: str) -> GuardResult:
    """Valida e sanitiza a mensagem do usuário."""
    text = message.strip()
    if not text:
        return GuardResult(False, text, "mensagem vazia")
    if len(text) > MAX_MESSAGE_CHARS:
        return GuardResult(False, text, f"mensagem acima de {MAX_MESSAGE_CHARS} caracteres")
    if _INJECTION_RE.search(text):
        return GuardResult(False, text, "possível prompt injection")
    return GuardResult(True, _mask_sensitive(text))


def check_output(answer: str) -> GuardResult:
    """Sanitiza a resposta antes de entregá-la ao usuário."""
    if not answer.strip():
        return GuardResult(False, answer, "resposta vazia")
    return GuardResult(True, _mask_sensitive(answer))
