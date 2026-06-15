$ErrorActionPreference = "Stop"

# Define Paths
$srcDir = "C:\src"
$zipPath = "$srcDir\flutter.zip"
$flutterBin = "$srcDir\flutter\bin\flutter.bat"
$downloadUrl = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.22.2-stable.zip"
$projectDir = "C:\Users\acer\OneDrive\Desktop\main\flutter_billing_app-main\flutter_billing_app-main"

# 1. Create source directory
if (-not (Test-Path $srcDir)) {
    Write-Host "Creating directory $srcDir..."
    New-Item -ItemType Directory -Force -Path $srcDir
}

# 2. Download Flutter SDK Zip
if (-not (Test-Path $zipPath)) {
    Write-Host "Downloading Flutter SDK (v3.22.2) from $downloadUrl..."
    Write-Host "This is a large file (~1GB). Please wait..."
    Import-Module BitsTransfer
    Start-BitsTransfer -Source $downloadUrl -Destination $zipPath -DisplayName "Downloading Flutter"
} else {
    Write-Host "Flutter zip already downloaded."
}

# 3. Extract Zip File
if (-not (Test-Path "$srcDir\flutter")) {
    Write-Host "Extracting Flutter SDK to $srcDir..."
    Expand-Archive -Path $zipPath -DestinationPath $srcDir -Force
} else {
    Write-Host "Flutter folder already extracted."
}

# 4. Verify Flutter installation
Write-Host "Verifying Flutter..."
try { & $flutterBin doctor --android-licenses } catch {}
& $flutterBin doctor

# 5. Build Project
Write-Host "Going to project directory: $projectDir"
Set-Location $projectDir

Write-Host "Running flutter pub get..."
& $flutterBin pub get

Write-Host "Running build_runner..."
& $flutterBin pub run build_runner build --delete-conflicting-outputs

Write-Host "Building release APK..."
& $flutterBin build apk --release

Write-Host "Finished successfully! APK is located at: $projectDir\build\app\outputs\flutter-apk\app-release.apk"
