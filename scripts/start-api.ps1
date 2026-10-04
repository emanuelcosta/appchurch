param(
  [int]$Port = 3000
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $root '.env'

if (-not (Test-Path $envFile)) {
  throw "Arquivo .env não encontrado: $envFile"
}

Get-Content $envFile | ForEach-Object {
  if ($_ -match '^([^#][^=]+)=(.*)$') {
    Set-Item -Path ('Env:' + $matches[1].Trim()) -Value $matches[2].Trim()
  }
}

$env:API_PORT = $Port
Set-Location $root
Write-Host "Iniciando API na porta $Port. Deixe este terminal aberto."
npm --prefix apps/api start
