"""Rotas HTTP do chat. Aqui só recebemos e devolvemos dados; a lógica está em `services`."""
from fastapi import APIRouter

from models.requests import ChatRequest
from models.responses import ChatResponse
from services import chat_service

router = APIRouter(prefix="/api", tags=["Chat"])


@router.post("/chat", response_model=ChatResponse, summary="Conversar com o Concierge")
async def chat(request: ChatRequest) -> ChatResponse:
    """Envia uma mensagem ao Concierge e devolve a resposta.

    A conversa é mantida por `user_id`: mensagens seguintes do mesmo usuário
    continuam o mesmo contexto.
    """
    result = await chat_service.chat(request.user_id, request.message)
    return ChatResponse(
        answer=result.answer,
        session_id=result.session_id,
        specialists=result.specialists,
        blocked=result.blocked,
    )
