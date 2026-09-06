$ErrorActionPreference = 'Stop'

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw 'Flutter is not available on PATH. Install Flutter first: https://docs.flutter.dev/get-started/install'
}

Write-Host 'Generating Flutter platform scaffolding...'
flutter create . --platforms=android,ios,windows --project-name gerards_paddestoelen_wegwijzer --org nl.natuurgids

Write-Host 'Configuring generated mobile platform floors...'
python tool/configure_generated_platforms.py

Write-Host 'Generating brand icon source...'
python tool/generate_app_icon.py

Write-Host 'Installing dependencies...'
flutter pub get

Write-Host 'Generating launcher icons...'
dart run flutter_launcher_icons
if (Test-Path 'windows') {
  dart run flutter_launcher_icons -f tool/windows_launcher_icons.yaml
}

Write-Host 'Running analyzer...'
flutter analyze

Write-Host 'Running tests...'
flutter test

Write-Host 'Bootstrap complete. Run Android with: flutter run. Run Windows with: flutter run -d windows'
