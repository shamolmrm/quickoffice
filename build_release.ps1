# Builds both store apps (needs keys.json + android/key.properties).
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
flutter clean
$env:QS_UPLOAD = '1'
flutter build appbundle --release --flavor free --dart-define-from-file=keys.json
flutter build appbundle --release --flavor pro --dart-define-from-file=keys.json --dart-define=PRO=true
flutter build apk --release --flavor free --dart-define-from-file=keys.json
flutter build apk --release --flavor pro --dart-define-from-file=keys.json --dart-define=PRO=true
