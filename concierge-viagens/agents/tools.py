"""Ferramentas (function tools) que os subagentes podem chamar.

O ADK transforma funções Python comuns em ferramentas para o modelo. Duas regras
importantes para isso funcionar bem:

1. Os *type hints* definem o schema dos parâmetros.
2. A *docstring* é o que o modelo lê para decidir QUANDO e COMO usar a função.
   Docstring ruim = ferramenta mal usada.

Convenção adotada aqui: toda ferramenta devolve um dict com a chave "status"
("ok" ou "erro"), para o modelo saber se deu certo e poder explicar o problema.
"""
import json
import math
import unicodedata

import httpx

from .config import DESTINOS_FILE


def _normalizar(texto: str) -> str:
    """Minúsculas e sem acentos, para comparar textos de forma tolerante."""
    sem_acento = unicodedata.normalize("NFD", texto)
    return "".join(c for c in sem_acento if unicodedata.category(c) != "Mn").lower().strip()


def buscar_destinos(interesse: str, clima: str, diaria_maxima_brl: float) -> dict:
    """Busca destinos de viagem no Brasil na base do Concierge.

    Args:
        interesse: tipo de experiência desejada. Valores comuns: "praia", "natureza",
            "cultura", "gastronomia", "aventura". Use "" se o usuário não disse.
        clima: clima preferido: "quente", "ameno" ou "frio". Use "" se não informado.
        diaria_maxima_brl: valor máximo de hospedagem por diária, em reais.
            Use 0 se o usuário não informou limite.

    Returns:
        Dict com "status" e a lista "destinos" (até 5), ordenada da hospedagem mais
        barata para a mais cara. Cada destino traz cidade, estado, perfis, clima,
        diária média, gasto diário médio, melhor época e destaques.
    """
    try:
        destinos = json.loads(DESTINOS_FILE.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return {"status": "erro", "mensagem": f"Base de destinos indisponível: {exc}"}

    interesse_n, clima_n = _normalizar(interesse), _normalizar(clima)

    def combina(destino: dict) -> bool:
        if interesse_n and interesse_n not in [_normalizar(p) for p in destino["perfis"]]:
            return False
        if clima_n and clima_n != _normalizar(destino["clima"]):
            return False
        if diaria_maxima_brl > 0 and destino["diaria_media_brl"] > diaria_maxima_brl:
            return False
        return True

    encontrados = sorted(filter(combina, destinos), key=lambda d: d["diaria_media_brl"])[:5]
    if not encontrados:
        return {"status": "ok", "destinos": [], "mensagem": "Nenhum destino atende a esses filtros."}
    return {"status": "ok", "destinos": encontrados}


async def obter_clima(cidade: str) -> dict:
    """Consulta a previsão do tempo dos próximos 5 dias para uma cidade.

    Args:
        cidade: nome da cidade, por exemplo "Recife" ou "Florianópolis".

    Returns:
        Dict com "status" e, se der certo, a "previsao": uma lista com data,
        temperatura mínima e máxima (°C) e probabilidade de chuva (%) por dia.
    """
    # Open-Meteo é uma API pública e gratuita, sem necessidade de chave.
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            geo = await client.get(
                "https://geocoding-api.open-meteo.com/v1/search",
                params={"name": cidade, "count": 1, "language": "pt"},
            )
            geo.raise_for_status()
            resultados = geo.json().get("results") or []
            if not resultados:
                return {"status": "erro", "mensagem": f"Cidade '{cidade}' não encontrada."}
            local = resultados[0]

            previsao = await client.get(
                "https://api.open-meteo.com/v1/forecast",
                params={
                    "latitude": local["latitude"],
                    "longitude": local["longitude"],
                    "daily": "temperature_2m_max,temperature_2m_min,precipitation_probability_max",
                    "timezone": "auto",
                    "forecast_days": 5,
                },
            )
            previsao.raise_for_status()
            diario = previsao.json()["daily"]
    except httpx.HTTPError as exc:
        return {"status": "erro", "mensagem": f"Serviço de clima indisponível: {exc}"}

    dias = [
        {
            "data": data,
            "minima_c": minima,
            "maxima_c": maxima,
            "chance_de_chuva_pct": chuva,
        }
        for data, minima, maxima, chuva in zip(
            diario["time"],
            diario["temperature_2m_min"],
            diario["temperature_2m_max"],
            diario["precipitation_probability_max"],
        )
    ]
    return {"status": "ok", "cidade": local["name"], "pais": local.get("country", ""), "previsao": dias}


def calcular_orcamento(
    dias: int,
    pessoas: int,
    passagem_por_pessoa_brl: float,
    diaria_hospedagem_brl: float,
    gasto_diario_por_pessoa_brl: float,
) -> dict:
    """Calcula o custo total estimado de uma viagem.

    Use SEMPRE esta função para contas de orçamento: modelos de linguagem erram
    aritmética, ferramentas não.

    Args:
        dias: número de diárias de hospedagem (mínimo 1).
        pessoas: número de viajantes (mínimo 1).
        passagem_por_pessoa_brl: custo de ida e volta por pessoa, em reais.
        diaria_hospedagem_brl: valor de UM quarto por diária, em reais.
        gasto_diario_por_pessoa_brl: alimentação e passeios por pessoa por dia, em reais.

    Returns:
        Dict com "status", o detalhamento por categoria, o "total_brl" e as
        "premissas" usadas no cálculo (apresente-as ao usuário).
    """
    if dias < 1 or pessoas < 1:
        return {"status": "erro", "mensagem": "Dias e pessoas devem ser pelo menos 1."}
    if min(passagem_por_pessoa_brl, diaria_hospedagem_brl, gasto_diario_por_pessoa_brl) < 0:
        return {"status": "erro", "mensagem": "Valores em reais não podem ser negativos."}

    quartos = math.ceil(pessoas / 2)  # premissa: 2 pessoas por quarto
    passagens = pessoas * passagem_por_pessoa_brl
    hospedagem = dias * quartos * diaria_hospedagem_brl
    gastos = dias * pessoas * gasto_diario_por_pessoa_brl
    total = passagens + hospedagem + gastos

    return {
        "status": "ok",
        "passagens_brl": round(passagens, 2),
        "hospedagem_brl": round(hospedagem, 2),
        "alimentacao_e_passeios_brl": round(gastos, 2),
        "total_brl": round(total, 2),
        "por_pessoa_brl": round(total / pessoas, 2),
        "premissas": [
            f"{quartos} quarto(s), considerando 2 pessoas por quarto",
            f"{dias} diária(s) de hospedagem",
            "valores informados pelo usuário ou médios da base; podem variar",
        ],
    }
