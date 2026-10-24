from pydantic import BaseModel, Field


class ChatResponse(BaseModel):
    """Resposta de POST /api/chat."""

    answer: str = Field(description="Texto da resposta do Concierge.")
    session_id: str = Field(description="Sessão (conversa) usada neste atendimento.")
    specialists: list[str] = Field(
        default_factory=list,
        description="Especialistas acionados pelo orquestrador nesta resposta.",
    )
    blocked: bool = Field(
        default=False,
        description="True quando um guardrail impediu o processamento da mensagem.",
    )
