$ErrorActionPreference = 'Stop'

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw 'Flutter is not available on PATH. Install Flutter first: https://docs.flutter.dev/get-started/install'
}

Write-Host 'Generating Flutter platform scaffolding...'
flutter create . --platforms=android,ios --project-name gerards_paddestoelen_wegwijzer --org nl.natuurgids

Write-Host 'Installing dependencies...'
flutter pub get

Write-Host 'Running analyzer...'
flutter analyze

Write-Host 'Running tests...'
flutter test

Write-Host 'Bootstrap complete. Run: flutter run'
