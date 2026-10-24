from pydantic import BaseModel, Field


class ChatRequest(BaseModel):
    """Corpo da requisição de POST /api/chat."""

    user_id: str = Field(
        min_length=1,
        max_length=64,
        description="Identificador estável do usuário. Cada usuário tem a sua própria conversa.",
        examples=["aluno-42"],
    )
    message: str = Field(
        min_length=1,
        max_length=2000,
        description="Mensagem do usuário para o Concierge.",
        examples=["Quero uma praia quente com diária de até R$ 500"],
    )
