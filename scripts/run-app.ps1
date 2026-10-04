param(
  [string]$Device,
  [string]$ApiUrl = 'http://192.168.18.238:3000'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $root '.env'
if (-not (Test-Path $envFile)) {
  throw "Arquivo .env não encontrado: $envFile"
}

Write-Host 'Usando o dispositivo Flutter conectado automaticamente.'

Get-Content $envFile | ForEach-Object {
  if ($_ -match '^([^#][^=]+)=(.*)$') {
    Set-Item -Path ('Env:' + $matches[1].Trim()) -Value $matches[2].Trim()
  }
}

if ([string]::IsNullOrWhiteSpace($env:SUPABASE_ANON_KEY)) {
  throw 'SUPABASE_ANON_KEY não está definida no arquivo .env.'
}

Set-Location (Join-Path $root 'appchurch')
$defines = @(
  "--dart-define=API_URL=$ApiUrl",
  "--dart-define=SUPABASE_URL=$env:SUPABASE_URL",
  "--dart-define=SUPABASE_ANON_KEY=$env:SUPABASE_ANON_KEY",
  "--dart-define=CONGREGATION_ID=f4f1212d-b728-4a42-8fee-fec6abab33f1"
)

if ([string]::IsNullOrWhiteSpace($Device)) {
  flutter run @defines
} else {
  flutter run -d $Device @defines
}
