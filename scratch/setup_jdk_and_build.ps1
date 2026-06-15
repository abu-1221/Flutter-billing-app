$ErrorActionPreference = "Stop"

# Define Paths
$srcDir = "C:\src"
$jdkZipPath = "$srcDir\jdk.zip"
$jdkDestDir = "$srcDir\jdk"
$downloadUrl = "https://api.adoptium.net/v3/binary/latest/17/ga/windows/x64/jdk/hotspot/normal/eclipse?project=jdk"
$flutterBin = "$srcDir\flutter\bin\flutter.bat"
$projectDir = "C:\Users\acer\OneDrive\Desktop\main\flutter_billing_app-main\flutter_billing_app-main"

# Redirect environment variables to D drive to bypass C drive space issues
$env:TEMP = 'D:\temp'
$env:TMP = 'D:\temp'
$env:GRADLE_USER_HOME = 'D:\.gradle'
$env:PUB_CACHE = 'D:\.pub-cache'

# 1. Download OpenJDK 17 Zip
if (-not (Test-Path $jdkZipPath)) {
    Write-Host "Downloading Portable JDK 17 from $downloadUrl..."
    Write-Host "Please wait..."
    Import-Module BitsTransfer
    Start-BitsTransfer -Source $downloadUrl -Destination $jdkZipPath -DisplayName "Downloading JDK 17"
} else {
    Write-Host "JDK zip already downloaded."
}

# 2. Extract JDK Zip
if (-not (Test-Path $jdkDestDir)) {
    Write-Host "Creating directory $jdkDestDir..."
    New-Item -ItemType Directory -Force -Path $jdkDestDir
    Write-Host "Extracting JDK to $jdkDestDir..."
    Expand-Archive -Path $jdkZipPath -DestinationPath $jdkDestDir -Force
} else {
    Write-Host "JDK already extracted."
}

# 3. Dynamically locate the JDK home directory inside extracted folder
$jdkHome = (Get-ChildItem -Path $jdkDestDir -Directory | Select-Object -First 1).FullName
Write-Host "Located JDK Home: $jdkHome"

# 4. Configure Environment Variables for this process
$env:JAVA_HOME = $jdkHome
$env:PATH = "$jdkHome\bin;$env:PATH"

# Verify java version
Write-Host "Checking Java Version..."
java -version

# 5. Accept Android Licenses automatically
Write-Host "Accepting Android Licenses..."
$yesList = @("y", "y", "y", "y", "y", "y", "y", "y", "y", "y")
$inputString = ($yesList -join "`n") + "`n"
$inputString | & $flutterBin doctor --android-licenses

# 6. Verify flutter doctor
& $flutterBin doctor

# 7. Compile Release APK
Write-Host "Navigating to project directory: $projectDir"
Set-Location $projectDir

Write-Host "Building release APK..."
& $flutterBin build apk --release

Write-Host "Finished successfully! APK is located at: $projectDir\build\app\outputs\flutter-apk\app-release.apk"
