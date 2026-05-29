$javaOk = $false
$java = Get-Command java -ErrorAction SilentlyContinue
if ($java) {
    $version = (java -version 2>&1 | Select-Object -First 1).ToString()
    if ($version -match '"(\d+)') {
        $major = [int]$Matches[1]
        if ($major -ge 21) {
            Write-Host "Java $major found - OK"
            $javaOk = $true
        } else {
            Write-Host "Java $major found but need 21+. Upgrading..."
        }
    }
} else {
    Write-Host "Java not found. Installing..."
}
if (-not $javaOk) {
    $javaInstaller = "$env:TEMP\java21.msi"
    Invoke-WebRequest -Uri "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.11%2B10/OpenJDK21U-jdk_x64_windows_hotspot_21.0.11_10.msi" -OutFile $javaInstaller
    Start-Process msiexec.exe -Wait -ArgumentList "/i $javaInstaller /quiet /norestart"
    Remove-Item $javaInstaller -Force
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
    Write-Host "Java 21 installed!"
}
$javaExe = (Get-Command java -ErrorAction SilentlyContinue)
if ($javaExe) {
    $javaPath = $javaExe.Source
} else {
    $javaPath = Get-ChildItem "C:\Program Files\Eclipse Adoptium" -Recurse -Filter "java.exe" -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
    if (-not $javaPath) {
        $javaPath = Get-ChildItem "C:\Program Files\Java" -Recurse -Filter "java.exe" -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
    }
}
if (-not $javaPath) {
    Write-Host "ERROR: Java executable not found. Please restart PowerShell and run the script again."
    exit
}
Write-Host "Using Java at: $javaPath"
$launcherProfiles = "$env:APPDATA\.minecraft\launcher_profiles.json"
$neoforgeInstalled = $false
if (Test-Path $launcherProfiles) {
    $profiles = Get-Content $launcherProfiles | ConvertFrom-Json
    $neoforgeProfile = $profiles.profiles.PSObject.Properties | Where-Object {$_.Value.lastVersionId -like "*neoforge*21.1.228*"}
    if ($neoforgeProfile) { $neoforgeInstalled = $true }
}
if (-not $neoforgeInstalled) {
    Write-Host "Downloading NeoForge installer..."
    $neoforgeInstaller = "$env:TEMP\neoforge-installer.jar"
    Invoke-WebRequest -Uri "https://maven.neoforged.net/releases/net/neoforged/neoforge/21.1.228/neoforge-21.1.228-installer.jar" -OutFile $neoforgeInstaller
    Write-Host "IMPORTANT: A window will open - click Install Client then OK. Come back here when done."
    Start-Process $javaPath -Wait -ArgumentList "-jar $neoforgeInstaller"
    Remove-Item $neoforgeInstaller -Force
} else {
    Write-Host "NeoForge 21.1.228 already installed."
}
$profiles = Get-Content $launcherProfiles | ConvertFrom-Json
$profiles.profiles.PSObject.Properties | Where-Object {$_.Value.lastVersionId -like "*neoforge*"} | ForEach-Object {
    $_.Value | Add-Member -MemberType NoteProperty -Name "gameDir" -Value "$env:APPDATA\.minecraft" -Force
}
$profiles | ConvertTo-Json -Depth 10 | Set-Content $launcherProfiles
Write-Host "NeoForge game directory set to $env:APPDATA\.minecraft"
$url = "https://github.com/syntaxy101/oasis-mods/raw/main/oasis-client-mods.zip"
$zip = "$env:TEMP\oasis-client-mods.zip"
$mods = "$env:APPDATA\.minecraft\mods"
New-Item -ItemType Directory -Force -Path $mods
Write-Host "Downloading mods..."
Invoke-WebRequest -Uri $url -OutFile $zip
Add-Type -Assembly System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::OpenRead($zip)
foreach ($entry in $archive.Entries) {
    if ($entry.Name -ne "") {
        $dest = Join-Path $mods $entry.Name
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $dest, $true)
    }
}
$archive.Dispose()
Remove-Item $zip -Force
$modCount = (Get-ChildItem $mods -Filter "*.jar").Count
Write-Host ""
Write-Host "==============================="
Write-Host "Setup Complete!"
Write-Host "Mods installed: $modCount / 31"
if ($modCount -ge 31) {
    Write-Host "ALL GOOD - open Minecraft launcher, select NeoForge 1.21.1 and Play!"
} else {
    Write-Host "WARNING: Expected 31 mods but got $modCount"
}
Write-Host "==============================="
