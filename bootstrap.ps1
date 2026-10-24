# Ponto de entrada para Windows (PowerShell 5.1+ ou 7).
#
#   .\bootstrap.cmd               -> (recomendado) funciona em cmd e PowerShell
#   .\bootstrap.ps1               -> instala o `make` (se faltar) e roda `make setup`
#   .\bootstrap.ps1 check         -> idem, mas roda `make check` (ou clean, ...)
#
# Se não for possível instalar o `make`, o setup roda direto pelos scripts
# (scripts\setup.ps1), então o aluno nunca fica travado.

param([string]$Target = "setup")

$ErrorActionPreference = "Stop"
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
Set-Location $PSScriptRoot

$UseColor = -not $env:NO_COLOR
$I_OK   = [string][char]0x2714
$I_WARN = [string][char]0x25B2
$I_RUN  = [string][char]0x2026
$I_DOT  = [string][char]0x25C6

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

function Has($cmd) { [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }

# Reconstrói o PATH da sessão (um programa recém-instalado só aparece em terminais novos).
function Refresh-Path {
    $machine = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $user    = [Environment]::GetEnvironmentVariable("Path", "User")
    $extra   = @(
        "$env:LOCALAPPDATA\Microsoft\WinGet\Links",
        "$env:ProgramData\chocolatey\bin",
        "$env:USERPROFILE\scoop\shims"
    ) -join ";"
    $env:Path = "$env:Path;$machine;$user;$extra"
}

function Find-Make {
    foreach ($c in @("make", "mingw32-make", "gmake")) {
        if (Has $c) { return $c }
    }
    return $null
}

function Install-Make {
    if (Has "winget") {
        Info "Instalando make via winget"
        winget install --id ezwinports.make -e --accept-source-agreements --accept-package-agreements | Out-Null
        if ($LASTEXITCODE -eq 0) { return $true }
    }
    if (Has "choco") {
        Info "Instalando make via Chocolatey"
        choco install make -y | Out-Null
        if ($LASTEXITCODE -eq 0) { return $true }
    }
    if (Has "scoop") {
        Info "Instalando make via Scoop"
        scoop install make | Out-Null
        if ($LASTEXITCODE -eq 0) { return $true }
    }
    return $false
}

# ---------- main -------------------------------------------------------------
Write-Host ""
Out-Parts @(@("$I_DOT ", "Magenta"), @("Google ADK ", "White"), @("· bootstrap", "DarkGray"))
Write-Host ""

Refresh-Path
$make = Find-Make
if ($make) {
    Ok "make já instalado" $make
} else {
    Info "make não encontrado, tentando instalar"
    $installed = $false
    try { $installed = Install-Make } catch { $installed = $false }
    Refresh-Path
    $make = Find-Make
    if ($installed -and $make) {
        Ok "make instalado" $make
    } else {
        Warn "Não consegui instalar o make automaticamente."
        Out-Parts @(,@("  Sem problema: vou rodar o setup direto pelos scripts.", "DarkGray"))
        $make = $null
    }
}

Write-Host ""
if ($make) {
    & $make $Target
    exit $LASTEXITCODE
}

# Fallback sem make: mapeia o alvo do Makefile para o comando do script.
$cmd = switch ($Target) { "setup" { "all" } "help" { "check" } default { $Target } }
& "$PSScriptRoot\scripts\setup.ps1" -Command $cmd
exit $LASTEXITCODE
