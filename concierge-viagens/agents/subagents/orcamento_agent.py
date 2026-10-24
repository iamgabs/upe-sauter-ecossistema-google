from google.adk.agents import Agent

from ..config import MODEL
from ..tools import calcular_orcamento
from .prompts import ORCAMENTO_PROMPT

orcamento_agent = Agent(
    name="orcamento_agent",
    model=MODEL,
    description=(
        "Calcula o custo total estimado de uma viagem (passagens, hospedagem, "
        "alimentação e passeios) a partir de dias, pessoas e valores."
    ),
    instruction=ORCAMENTO_PROMPT,
    tools=[calcular_orcamento],
)
