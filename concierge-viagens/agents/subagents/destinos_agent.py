from google.adk.agents import Agent

from ..config import MODEL
from ..tools import buscar_destinos
from .prompts import DESTINOS_PROMPT

# O `description` NÃO é enfeite: quando este agente vira uma ferramenta do agente
# raiz, é esse texto que o orquestrador lê para decidir se deve chamá-lo.
destinos_agent = Agent(
    name="destinos_agent",
    model=MODEL,
    description=(
        "Recomenda destinos de viagem no Brasil conforme interesse (praia, natureza, "
        "cultura, gastronomia, aventura), clima preferido e limite de gasto com hospedagem."
    ),
    instruction=DESTINOS_PROMPT,
    tools=[buscar_destinos],
)
