$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

Push-Location (Join-Path $root 'apps/api')
try { npm test } finally { Pop-Location }

Push-Location (Join-Path $root 'apps/worker')
try { npm test } finally { Pop-Location }

Push-Location (Join-Path $root 'appchurch')
try { flutter analyze; flutter test } finally { Pop-Location }

Write-Host 'Testes concluídos com sucesso.'
