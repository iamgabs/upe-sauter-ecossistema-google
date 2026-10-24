"""Ponto de entrada da aplicação web (FastAPI).

Rodar em desenvolvimento (com o ambiente virtual ativado, dentro desta pasta):

    uvicorn main:app --reload

Depois abra http://127.0.0.1:8000 para o chat, ou /docs para a documentação interativa da API.
"""
import logging
import os

import uvicorn
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

import config
from api.chat_controller import router as chat_router
from utils.logging_config import setup_logging

setup_logging()
logger = logging.getLogger("app")

# Sem credenciais o servidor sobe, mas toda conversa falharia: melhor avisar logo no início.
if not (os.getenv("GOOGLE_API_KEY") or os.getenv("GOOGLE_GENAI_USE_VERTEXAI", "").upper() == "TRUE"):
    logger.warning("GOOGLE_API_KEY não definida. Copie .env.example para .env e preencha a chave.")

app = FastAPI(
    title="Concierge de Viagens",
    description="API de exemplo: orquestrador de agentes (Google ADK) para planejar viagens.",
    version="1.0.0",
)

app.include_router(chat_router)


@app.get("/api/health", tags=["Infra"], summary="Health check")
async def health() -> dict:
    return {"status": "ok"}


# A interface de chat é servida na raiz. O mount vem POR ÚLTIMO para não "engolir" as rotas da API.
app.mount("/", StaticFiles(directory=config.STATIC_DIR, html=True), name="static")


if __name__ == "__main__":
    uvicorn.run("main:app", host=config.HOST, port=config.PORT, reload=True)
