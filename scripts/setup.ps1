# Setup para Windows (PowerShell 5.1+ ou PowerShell 7).
# Uso: powershell -ExecutionPolicy Bypass -File scripts/setup.ps1 [all|check|uv|python|venv|adk|clean]
#
# Cada passo é idempotente: só instala se ainda não estiver instalado.
# Cores podem ser desligadas com NO_COLOR=1.

param([string]$Command = "all")

$ErrorActionPreference = "Stop"
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$PythonVersion = if ($env:PYTHON_VERSION) { $env:PYTHON_VERSION } else { "3.12" }
$Venv          = if ($env:VENV) { $env:VENV } else { ".venv" }
$UseColor      = -not $env:NO_COLOR

# ---------- estilo -----------------------------------------------------------
$I_OK    = [string][char]0x2714   # ✔
$I_ERR   = [string][char]0x2716   # ✖
$I_WARN  = [string][char]0x25B2   # ▲
$I_RUN   = [string][char]0x2026   # …
$I_ARROW = [string][char]0x25B8   # ▸
$I_DOT   = [string][char]0x25C6   # ◆
$I_SEP   = [string][char]0x00B7   # ·

# Escreve segmentos coloridos na mesma linha: Out-Parts @(@("texto","Cor"), ...)
function Out-Parts($parts) {
    foreach ($p in $parts) {
        if ($UseColor -and $p[1]) { Write-Host $p[0] -NoNewline -ForegroundColor $p[1] }
        else { Write-Host $p[0] -NoNewline }
    }
    Write-Host ""
}

function Ok($msg, $detail = "") {
    $parts = @(@("  $I_OK ", "Green"), @($msg, $null))
    if ($detail) { $parts += ,@("  $detail", "DarkGray") }
    Out-Parts $parts
}
function Info($msg) { Out-Parts @(,@("  $I_RUN $msg", "DarkGray")) }
function Warn($msg) { Out-Parts @(@("  $I_WARN ", "Yellow"), @($msg, $null)) }
function Die($msg)  { Out-Parts @(,@("  $I_ERR $msg", "Red")); exit 1 }
function Fail($msg, $detail) {
    Out-Parts @(@("  $I_ERR ", "Red"), @($msg, $null), @("  $detail", "DarkGray"))
}
function Section($tag, $title) {
    Write-Host ""
    Out-Parts @(@($tag, "Cyan"), @(" $title", "White"))
}
function Banner-Title($title) {
    Write-Host ""
    Out-Parts @(@("$I_DOT ", "Magenta"), @($title, "White"))
}

function Has($cmd) { [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }

# Executa um comando nativo sem poluir a tela; em caso de falha mostra a saída e retorna $false.
function Quiet([scriptblock]$Block) {
    $old = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $out = & $Block 2>&1
        if ($LASTEXITCODE -ne 0) { $out | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }; return $false }
        return $true
    } catch { Write-Host "    $_" -ForegroundColor DarkGray; return $false }
    finally { $ErrorActionPreference = $old }
}

# Executa um comando nativo e retorna $true se terminou com sucesso (sem saída).
function Try-Native([scriptblock]$Block) {
    $old = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try { & $Block *> $null; return ($LASTEXITCODE -eq 0) }
    catch { return $false }
    finally { $ErrorActionPreference = $old }
}

function Venv-Python {
    $p = Join-Path $Venv "Scripts\python.exe"
    if (Test-Path $p) { return $p }
    return $null
}

# O instalador do uv coloca o binário em ~/.local/bin (nem sempre já está no PATH).
function Add-UvToPath {
    $dirs = @("$env:USERPROFILE\.local\bin", "$env:USERPROFILE\.cargo\bin")
    foreach ($d in $dirs) {
        if ((Test-Path $d) -and ($env:Path -notlike "*$d*")) { $env:Path = "$d;$env:Path" }
    }
}

# Roda fora do projeto para não "achar" o python do próprio .venv.
function Find-Python {
    $old = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    Push-Location $env:USERPROFILE
    try {
        $out = & uv python find $PythonVersion 2>$null
        if ($LASTEXITCODE -eq 0 -and $out) { return ($out | Select-Object -First 1) }
        return $null
    } finally { Pop-Location; $ErrorActionPreference = $old }
}

function Uv-Version  { (& uv --version) -replace "^uv\s+(\S+).*", '$1' }
function Venv-Ok     { $p = Venv-Python; [bool]($p -and (Try-Native { & $p -c "import sys" })) }
function Adk-Ok      { (Has "uv") -and (Venv-Python) -and (Try-Native { uv pip show --python (Venv-Python) google-adk }) }
function Adk-Version {
    $line = uv pip show --python (Venv-Python) google-adk 2>$null | Where-Object { $_ -like "Version:*" } | Select-Object -First 1
    return ($line -replace "^Version:\s*", "")
}

function Banner {
    Banner-Title "Google ADK $I_SEP setup do ambiente"
    Out-Parts @(,@("  Python $PythonVersion  $I_SEP  venv em $Venv", "DarkGray"))
}

# ---------- passos -----------------------------------------------------------
function Step-Uv {
    Add-UvToPath
    if (Has "uv") { Ok "uv já instalado" "v$(Uv-Version)"; return }

    Info "uv não encontrado, instalando"
    $installed = $false
    try {
        Invoke-RestMethod https://astral.sh/uv/install.ps1 | Invoke-Expression *> $null
        $installed = $true
    } catch {
        if (Has "winget") {
            Info "Tentando via winget"
            $installed = Quiet { winget install --id astral-sh.uv -e --accept-source-agreements --accept-package-agreements }
        }
    }

    Add-UvToPath
    if (-not $installed -or -not (Has "uv")) {
        Die "Falha ao instalar o uv. Veja https://docs.astral.sh/uv/getting-started/installation/"
    }
    Ok "uv instalado" "v$(Uv-Version)"
}

function Step-Python {
    if (-not (Has "uv")) { Step-Uv }
    $py = Find-Python
    if ($py) { Ok "Python $PythonVersion já disponível" $py; return }

    Info "Python $PythonVersion não encontrado, instalando via uv"
    if (-not (Quiet { uv python install $PythonVersion })) { Die "Falha ao instalar o Python $PythonVersion" }
    Ok "Python $PythonVersion instalado" (Find-Python)
}

function Step-Venv {
    if (-not (Has "uv")) { Step-Uv }
    if (-not (Find-Python)) { Step-Python }

    if (Venv-Ok) { Ok "Ambiente virtual já existe" $Venv; return }

    if (Test-Path $Venv) {
        Warn "$Venv existe mas está quebrado (ex.: criado em outro sistema), recriando"
        Remove-Item -Recurse -Force $Venv
    }
    Info "Criando ambiente virtual"
    if (-not (Quiet { uv venv $Venv --python $PythonVersion })) { Die "Falha ao criar o ambiente virtual" }
    Ok "Ambiente virtual criado" $Venv
}

function Step-Adk {
    if (-not (Venv-Ok)) { Step-Venv }

    if (Adk-Ok) { Ok "google-adk já instalado" "v$(Adk-Version)"; return }

    Info "Instalando google-adk (pode levar alguns segundos)"
    $vpy = Venv-Python
    if (-not (Quiet { uv pip install --python $vpy google-adk })) { Die "Falha ao instalar o google-adk" }
    Ok "google-adk instalado" "v$(Adk-Version)"
}

function Step-Check {
    Add-UvToPath
    $missing = $false
    Banner-Title "Verificando ambiente"
    Write-Host ""

    if (Has "uv") { Ok "uv" "v$(Uv-Version)" } else { Fail "uv" "não instalado"; $missing = $true }

    $py = if (Has "uv") { Find-Python } else { $null }
    if ($py) { Ok "Python $PythonVersion" $py } else { Fail "Python $PythonVersion" "não encontrado"; $missing = $true }

    if (Venv-Ok) {
        Ok "Ambiente virtual" $Venv
        if (Adk-Ok) { Ok "google-adk" "v$(Adk-Version)" } else { Fail "google-adk" "não instalado em $Venv"; $missing = $true }
    } else {
        Fail "Ambiente virtual" "$Venv não existe"; $missing = $true
    }

    Write-Host ""
    if ($missing) {
        Out-Parts @(@("  Faltam itens. ", "Yellow"), @("Rode: make setup", $null))
        Write-Host ""
        exit 1
    }
    Out-Parts @(,@("  $I_OK Tudo certo!", "Green"))
    Write-Host ""
}

function Step-Clean {
    Banner-Title "Limpando ambiente"
    Write-Host ""
    if (Test-Path $Venv) { Remove-Item -Recurse -Force $Venv; Ok "Removido" $Venv }
    else { Ok "Nada para remover" "$Venv não existe" }
    Write-Host ""
}

function Step-All {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    Banner

    Section "[1/4]" "uv";               Step-Uv
    Section "[2/4]" "Python";           Step-Python
    Section "[3/4]" "Ambiente virtual"; Step-Venv
    Section "[4/4]" "google-adk";       Step-Adk

    $secs = [int]$sw.Elapsed.TotalSeconds
    Write-Host ""
    Out-Parts @(@("$I_OK Ambiente pronto", "Green"), @(" ($($secs)s)", "DarkGray"))
    Write-Host ""
    Write-Host "  Ative o ambiente com:"
    Out-Parts @(,@("    $Venv\Scripts\Activate.ps1   (PowerShell)", "Cyan"))
    Out-Parts @(,@("    $Venv\Scripts\activate.bat   (cmd)", "Cyan"))
    Write-Host ""
}

# ---------- main -------------------------------------------------------------
switch ($Command) {
    "all"    { Step-All }
    "check"  { Step-Check }
    "uv"     { Section $I_ARROW "uv";               Step-Uv;     Write-Host "" }
    "python" { Section $I_ARROW "Python";           Step-Python; Write-Host "" }
    "venv"   { Section $I_ARROW "Ambiente virtual"; Step-Venv;   Write-Host "" }
    "adk"    { Section $I_ARROW "google-adk";       Step-Adk;    Write-Host "" }
    "clean"  { Step-Clean }
    default  { Die "Comando desconhecido: $Command (use: all|check|uv|python|venv|adk|clean)" }
}
