$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'No se pudieron resolver las dependencias.' }
flutter run -d chrome --web-port=3000 --dart-define=SUPABASE_URL="https://tgwihgzgzccjohvddawi.supabase.co" --dart-define=SUPABASE_PUBLISHABLE_KEY="sb_publishable_JUfxFcQfm-xu_Ffr2mYAPw_YiIDnBk5"
