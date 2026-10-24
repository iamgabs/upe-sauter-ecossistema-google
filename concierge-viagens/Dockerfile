FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

ENV PYTHONUNBUFFERED=1 \
    HOST=0.0.0.0 \
    PORT=8000

EXPOSE 8000

# A chave de API entra por variável de ambiente (nunca dentro da imagem):
#   docker run -p 8000:8000 --env-file .env concierge-viagens
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
