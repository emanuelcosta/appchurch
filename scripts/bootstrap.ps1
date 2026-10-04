$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

function Require-Command($name) {
  if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
    throw "Comando obrigatório não encontrado: $name"
  }
}

Require-Command node
Require-Command npm
Require-Command flutter

if (-not (Test-Path (Join-Path $root '.env'))) {
  Copy-Item (Join-Path $root '.env.example') (Join-Path $root '.env')
  Write-Host 'Criado .env a partir de .env.example. Revise os valores antes da integração.'
}

Push-Location (Join-Path $root 'apps/api')
try {
  npm install
  npm run build
  npm test
} finally {
  Pop-Location
}

Push-Location (Join-Path $root 'apps/worker')
try {
  npm install
  npm run build
} finally {
  Pop-Location
}

Push-Location (Join-Path $root 'appchurch')
try {
  flutter pub get
  dart run build_runner build
  flutter analyze
  flutter test
} finally {
  Pop-Location
}

Write-Host 'Bootstrap concluído. API: npm --prefix apps/api run start:dev'
Write-Host 'Flutter: flutter run --project appchurch'
