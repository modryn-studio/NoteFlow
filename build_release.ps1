# NoteFlow - Build Release Script
# Run this anytime you need to create a new release build

Write-Host "🚀 Building NoteFlow Release..." -ForegroundColor Cyan

# Check if key.properties exists
if (-not (Test-Path "android\key.properties")) {
    Write-Host "❌ Error: android\key.properties not found!" -ForegroundColor Red
    Write-Host "   Please create signing keys first." -ForegroundColor Yellow
    exit 1
}

# Clean previous builds
Write-Host "🧹 Cleaning previous builds..." -ForegroundColor Yellow
flutter clean

# Build App Bundle for Play Store
Write-Host "📦 Building App Bundle (AAB)..." -ForegroundColor Yellow
flutter build appbundle --release

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ Build successful!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📦 App Bundle location:" -ForegroundColor Cyan
    Write-Host "   build\app\outputs\bundle\release\app-release.aab" -ForegroundColor White
    Write-Host ""
    Write-Host "📱 To install on connected device:" -ForegroundColor Cyan
    Write-Host "   flutter build apk --release" -ForegroundColor White
    Write-Host "   adb install build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor White
    Write-Host ""
    Write-Host "☁️  Upload to Play Console:" -ForegroundColor Cyan
    Write-Host "   https://play.google.com/console" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host "❌ Build failed!" -ForegroundColor Red
    exit 1
}
