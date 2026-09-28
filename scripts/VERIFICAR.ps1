$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'Falló flutter pub get' }
flutter analyze --no-fatal-infos --no-fatal-warnings
if ($LASTEXITCODE -ne 0) { throw 'Falló el análisis Dart' }
flutter test
if ($LASTEXITCODE -ne 0) { throw 'Fallaron las pruebas Flutter' }
flutter build web --release --dart-define=SUPABASE_URL="https://tgwihgzgzccjohvddawi.supabase.co" --dart-define=SUPABASE_PUBLISHABLE_KEY="sb_publishable_JUfxFcQfm-xu_Ffr2mYAPw_YiIDnBk5"
if ($LASTEXITCODE -ne 0) { throw 'Falló la compilación web' }
