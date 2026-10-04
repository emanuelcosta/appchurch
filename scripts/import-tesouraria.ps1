$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$file = Join-Path $root 'TESOURARIA - ADTCSGA EIXO DO CARRO.xlsx'
if (-not (Test-Path $file)) {
  throw "Planilha não encontrada: $file"
}

Set-Location $root
python scripts/import-tesouraria.py --file $file --dry-run
Write-Host 'Prévia concluída. Revise import-preview.json antes de autorizar a gravação.'
