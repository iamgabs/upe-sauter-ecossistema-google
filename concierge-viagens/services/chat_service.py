"""Serviço de chat: liga a API web ao agente do ADK.

Responsabilidades (e a ordem em que acontecem):
    1. guardrail de entrada
    2. obter (ou criar) a sessão do usuário
    3. executar o agente com o Runner do ADK e acompanhar os eventos
    4. guardrail de saída
    5. registrar a interação

O controller HTTP só recebe e devolve JSON; toda a lógica fica aqui, o que permite
reaproveitá-la (por exemplo, num script ou num teste) sem subir o servidor.
"""
import asyncio
import logging
from dataclasses import dataclass, field

from google.adk.runners import Runner
from google.adk.sessions import InMemorySessionService
from google.genai.types import Content, Part

from agents.agent import root_agent
from config import ADK_APP_NAME, AGENT_TIMEOUT_SECONDS
from services import guardrails
from services.interaction_log import log_interaction

logger = logging.getLogger(__name__)

MSG_BLOQUEADA = "Não consegui processar essa mensagem. Pode reformular o seu pedido sobre a viagem?"
MSG_ERRO = "Tive um problema para responder agora. Pode tentar de novo em instantes?"

# SessionService guarda o histórico de cada conversa. A versão em memória some quando o
# servidor reinicia; o ADK também oferece serviços com persistência (banco de dados, nuvem).
_session_service = InMemorySessionService()

# O Runner é quem executa o agente: monta o contexto, chama o modelo, executa as
# ferramentas e devolve uma sequência de *eventos*.
_runner = Runner(
    agent=root_agent,
    app_name=ADK_APP_NAME,
    session_service=_session_service,
)

_session_lock = asyncio.Lock()


@dataclass
class ChatResult:
    answer: str
    session_id: str
    specialists: list[str] = field(default_factory=list)
    blocked: bool = False


def _session_id_for(user_id: str) -> str:
    return f"sessao-{user_id}"


async def _ensure_session(user_id: str) -> str:
    """Reaproveita a sessão do usuário (mantendo o contexto) ou cria a primeira."""
    session_id = _session_id_for(user_id)
    async with _session_lock:  # evita criar a mesma sessão em duas requisições simultâneas
        existing = await _session_service.get_session(
            app_name=ADK_APP_NAME, user_id=user_id, session_id=session_id
        )
        if existing is None:
            await _session_service.create_session(
                app_name=ADK_APP_NAME, user_id=user_id, session_id=session_id
            )
    return session_id


async def _run_agent(user_id: str, session_id: str, message: str) -> tuple[str, list[str]]:
    """Executa o agente e devolve (texto da resposta final, especialistas acionados)."""
    content = Content(role="user", parts=[Part(text=message)])
    specialists: list[str] = []
    answer_parts: list[str] = []

    async for event in _runner.run_async(user_id=user_id, session_id=session_id, new_message=content):
        # Eventos de "chamada de ferramenta": é assim que sabemos quem o orquestrador acionou.
        for call in event.get_function_calls():
            if call.name and call.name not in specialists:
                specialists.append(call.name)

        # O evento final traz o texto que vai para o usuário.
        if event.is_final_response() and event.content and event.content.parts:
            answer_parts.extend(part.text for part in event.content.parts if part.text)

    return "".join(answer_parts).strip(), specialists


async def chat(user_id: str, message: str) -> ChatResult:
    # 1. Guardrail de entrada
    entrada = guardrails.check_input(message)
    if not entrada.allowed:
        logger.warning("[CHAT] entrada bloqueada | user=%s | motivo=%s", user_id, entrada.reason)
        log_interaction(
            event="entrada_bloqueada", user_id=user_id, message=message, motivo=entrada.reason
        )
        return ChatResult(MSG_BLOQUEADA, _session_id_for(user_id), blocked=True)

    # 2. Sessão
    session_id = await _ensure_session(user_id)

    # 3. Agente
    specialists: list[str] = []
    try:
        answer, specialists = await asyncio.wait_for(
            _run_agent(user_id, session_id, entrada.text), timeout=AGENT_TIMEOUT_SECONDS
        )
    except Exception as exc:  # modelo fora do ar, chave inválida, timeout...
        logger.error("[CHAT] falha na execução do agente | user=%s | %r", user_id, exc, exc_info=True)
        log_interaction(
            event="erro", user_id=user_id, message=entrada.text, session_id=session_id, erro=repr(exc)
        )
        return ChatResult(MSG_ERRO, session_id, specialists)

    # 4. Guardrail de saída
    saida = guardrails.check_output(answer)
    if not saida.allowed:
        log_interaction(
            event="saida_bloqueada", user_id=user_id, message=entrada.text,
            session_id=session_id, motivo=saida.reason,
        )
        return ChatResult(MSG_ERRO, session_id, specialists, blocked=True)

    # 5. Log
    log_interaction(
        event="interacao", user_id=user_id, session_id=session_id,
        message=entrada.text, answer=saida.text, specialists=specialists,
    )
    logger.info(
        "[CHAT] user=%s especialistas=%s", user_id, ", ".join(specialists) or "nenhum (resposta direta)"
    )
    return ChatResult(saida.text, session_id, specialists)
