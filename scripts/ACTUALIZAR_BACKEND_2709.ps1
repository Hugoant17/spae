$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
Write-Host 'Antes de continuar, aplica las migraciones pendientes en Supabase SQL Editor (incluidas 270001 y 270002).'
& npx supabase login
if ($LASTEXITCODE -ne 0) { throw 'No se pudo iniciar sesión en Supabase.' }
& npx supabase functions deploy spae-api --project-ref tgwihgzgzccjohvddawi --no-verify-jwt
if ($LASTEXITCODE -ne 0) { throw 'Falló el despliegue de spae-api. No continúes con una versión antigua.' }
Write-Host 'Backend actualizado. Ejecuta VERIFICAR.ps1 y publica o inicia el Flutter de esta carpeta.'
