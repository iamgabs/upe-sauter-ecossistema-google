# UPE FacePE: agentes com Google ADK

Repositório educacional para aprender a criar agentes de IA no ecossistema Google com o [Agent Development Kit (ADK)](https://google.github.io/adk-docs/).

Antes de começar os tutoriais, configure o seu ambiente. É um único comando e ele funciona em macOS, Linux e Windows.

## Primeiros passos

1. Clone o repositório e entre na pasta:

   ```bash
   git clone <url-do-repositorio>
   cd upe-facepe
   ```

2. Rode o comando de configuração do seu sistema:

   | Sistema | Comando |
   |---|---|
   | macOS / Linux / WSL | `sh bootstrap.sh` |
   | Windows (cmd ou PowerShell) | `bootstrap.cmd` |

3. Ative o ambiente virtual:

   | Sistema | Comando |
   |---|---|
   | macOS / Linux / WSL | `source .venv/bin/activate` |
   | Windows (PowerShell) | `.venv\Scripts\Activate.ps1` |
   | Windows (cmd) | `.venv\Scripts\activate.bat` |

4. Confirme que o ADK está funcionando:

   ```bash
   adk --version
   ```

Pronto! Você já pode seguir os tutoriais.

## O que o setup faz

O `bootstrap` instala o `make` se ele não existir e depois executa `make setup`, que **verifica cada item e só instala o que estiver faltando**:

| Etapa | O que acontece |
|---|---|
| `make` | Instalado via Homebrew (macOS), gerenciador de pacotes do Linux (`apt`, `dnf`, `pacman`...) ou `winget`/`choco`/`scoop` (Windows) |
| [`uv`](https://docs.astral.sh/uv/) | Gerenciador de pacotes e versões do Python |
| Python 3.12 | Instalado pelo `uv` se você não tiver essa versão |
| Ambiente virtual | Criado na pasta `.venv` |
| `google-adk` | Instalado dentro do `.venv` (não afeta o Python do seu sistema) |

Pode rodar quantas vezes quiser: se já estiver tudo instalado, ele apenas confirma.

> Se o `bootstrap` não conseguir instalar o `make`, ele roda o setup direto pelos scripts em `scripts/`, então você não fica travado.

## Comandos disponíveis

Com o `make` instalado, use:

| Comando | Descrição |
|---|---|
| `make setup` | Verifica e instala tudo (`uv`, Python e `google-adk`) |
| `make check` | Só verifica o que já está instalado, sem instalar nada |
| `make clean` | Remove o ambiente virtual (`.venv`) |
| `make help` | Mostra a ajuda |
| `make uv` / `make python` / `make venv` / `make adk` | Executa uma etapa isolada |

Você pode trocar a versão do Python ou a pasta do ambiente:

```bash
make setup PYTHON_VERSION=3.13
make setup VENV=meu-ambiente
```

Para desligar as cores da saída, use `NO_COLOR=1` (ex.: `NO_COLOR=1 make setup`).

## Problemas comuns

**Windows: "a execução de scripts está desabilitada"**
Use `bootstrap.cmd` em vez de `bootstrap.ps1`. Ele libera a execução só para esse comando.

**Windows: o `make` foi instalado mas não é reconhecido**
Feche e abra o terminal para atualizar o PATH. O `bootstrap` já tenta contornar isso, mas alguns terminais só enxergam o `make` depois de reiniciados.

**macOS: abriu uma janela pedindo para instalar as "Command Line Tools"**
É o instalador do `make` da Apple. Confirme a instalação, espere terminar e rode `sh bootstrap.sh` de novo.

**Linux: pediu senha**
O `sudo` é usado apenas para instalar o `make` pelo gerenciador de pacotes.

**O `.venv` parou de funcionar** (por exemplo, foi copiado de outro computador ou sistema)
Rode `make clean` e depois `make setup`. O setup também detecta e recria um `.venv` quebrado automaticamente.

**`adk: command not found`**
O ambiente virtual não está ativado. Veja o passo 3 de [Primeiros passos](#primeiros-passos).

## Projeto de exemplo

Em [`concierge-viagens/`](concierge-viagens/README.md) há uma aplicação completa: um **orquestrador de agentes** (Google ADK) exposto por uma **API FastAPI** com interface de chat. É a referência de como organizar um projeto real: agentes, ferramentas, sessões, guardrails e logs. Depois do setup:

```bash
cd concierge-viagens
cp .env.example .env     # preencha GOOGLE_API_KEY (Windows cmd: copy .env.example .env)
uvicorn main:app --reload
```

## Estrutura do repositório

```
.
├── concierge-viagens/                             # projeto de exemplo (agentes + API web)
├── bootstrap.sh / bootstrap.cmd / bootstrap.ps1   # ponto de entrada: instala o make e roda o setup
├── Makefile                                       # comandos (setup, check, clean...)
├── scripts/
│   ├── setup.sh                                   # setup para macOS / Linux / WSL / Git Bash
│   └── setup.ps1                                  # setup para Windows
└── .venv/                                         # ambiente virtual (criado pelo setup, não vai para o Git)
```

## Chaves e segredos

Os tutoriais usarão um arquivo `.env` para guardar chaves de API (ex.: `GOOGLE_API_KEY`). Esse arquivo **nunca deve ser enviado ao Git**; o `.gitignore` já o ignora.
