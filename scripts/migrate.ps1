$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

if (-not (Get-Command supabase -ErrorAction SilentlyContinue)) {
  throw 'Supabase CLI não encontrada. Instale-a antes de aplicar migrations.'
}

Set-Location $root
supabase db push
