from google.adk.agents import Agent

from ..config import MODEL
from ..tools import obter_clima
from .prompts import CLIMA_PROMPT

clima_agent = Agent(
    name="clima_agent",
    model=MODEL,
    description=(
        "Informa a previsão do tempo dos próximos 5 dias para uma cidade "
        "(temperaturas e chance de chuva)."
    ),
    instruction=CLIMA_PROMPT,
    tools=[obter_clima],
)
