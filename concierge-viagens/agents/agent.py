"""Agente raiz (orquestrador) do Concierge de Viagens.

Arquitetura "orquestrador + especialistas":

    usuário ──► root_agent ──┬─► destinos_agent  ──► buscar_destinos()
                             ├─► clima_agent     ──► obter_clima()
                             └─► orcamento_agent ──► calcular_orcamento()

O agente raiz só decide quem deve responder. Cada especialista tem prompt, ferramentas
e responsabilidade próprios, o que deixa cada parte simples de testar e de evoluir.

A variável `root_agent` é um nome especial: é ela que o `adk web` e o `Runner` procuram.
"""
from google.adk.agents import Agent
from google.adk.tools.agent_tool import AgentTool

from .config import MODEL
from .root_prompt import ROOT_PROMPT
from .subagents import clima_agent, destinos_agent, orcamento_agent

# `AgentTool` embrulha um agente como se fosse uma função: o orquestrador chama o
# especialista, espera a resposta e continua no controle da conversa.
# (Alternativa: `sub_agents=[...]`, que *transfere* a conversa para o especialista.)
root_agent = Agent(
    name="concierge_agent",
    model=MODEL
    instruction=ROOT_PROMPT,
    tools=[
        AgentTool(destinos_agent),
        AgentTool(clima_agent),
        AgentTool(orcamento_agent),
    ],
)
