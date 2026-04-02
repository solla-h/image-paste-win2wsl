<#
.SYNOPSIS
    Clipboard image save pipeline diagnostic.
    Copy a screenshot to clipboard, then run this script.
.USAGE
    powershell -ExecutionPolicy Bypass -File "lib\diagnose-clipboard.ps1"
#>

$ErrorActionPreference = "Stop"

Write-Host "`n=== Clipboard Image Diagnostic ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"

# Step 1: Load assemblies
Write-Host "[1/6] Loading assemblies..." -NoNewline
try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    Write-Host " OK" -ForegroundColor Green
} catch {
    Write-Host " FAIL" -ForegroundColor Red
    Write-Host "  Error: $_"
    exit 1
}

# Step 2: Check clipboard formats
Write-Host "[2/6] Clipboard formats present:"
$dataObj = [System.Windows.Forms.Clipboard]::GetDataObject()
if ($null -eq $dataObj) {
    Write-Host "  Clipboard is EMPTY or inaccessible" -ForegroundColor Red
    exit 1
}
$formats = $dataObj.GetFormats()
foreach ($fmt in $formats) {
    Write-Host "  - $fmt" -ForegroundColor Yellow
}

# Step 3: ContainsImage check
Write-Host "`n[3/6] ContainsImage()..." -NoNewline
$hasImage = [System.Windows.Forms.Clipboard]::ContainsImage()
if ($hasImage) {
    Write-Host " TRUE" -ForegroundColor Green
} else {
    Write-Host " FALSE" -ForegroundColor Red
    Write-Host "  >> Clipboard has data but .NET does not recognize it as an image."
    Write-Host "  >> Your screenshot tool may use a format (PNG stream / file ref) that ContainsImage() ignores."

    # Check alternative formats
    $hasPng = $dataObj.GetDataPresent("PNG")
    $hasFileDrop = [System.Windows.Forms.Clipboard]::ContainsFileDropList()
    Write-Host "  PNG format present: $hasPng"
    Write-Host "  FileDrop present:   $hasFileDrop"

    if ($hasPng) {
        Write-Host "`n  >> ROOT CAUSE: Tool puts PNG stream, not CF_BITMAP. ContainsImage() misses it." -ForegroundColor Magenta
    }
    if ($hasFileDrop) {
        $files = [System.Windows.Forms.Clipboard]::GetFileDropList()
        Write-Host "  Files: $($files -join ', ')"
        Write-Host "`n  >> ROOT CAUSE: Tool copies file path, not bitmap data." -ForegroundColor Magenta
    }
    exit 1
}

# Step 4: GetImage
Write-Host "[4/6] GetImage()..." -NoNewline
try {
    $image = [System.Windows.Forms.Clipboard]::GetImage()
    if ($null -eq $image) {
        Write-Host " NULL" -ForegroundColor Red
        Write-Host "  >> ContainsImage=true but GetImage returned null. Clipboard data corrupted or source app closed."
        exit 1
    }
    Write-Host " OK ($($image.Width)x$($image.Height))" -ForegroundColor Green
} catch {
    Write-Host " FAIL" -ForegroundColor Red
    Write-Host "  Error: $_"
    exit 1
}

# Step 5: SmartScale plugin
Write-Host "[5/6] SmartScale plugin..." -NoNewline
$pluginPath = Join-Path $PSScriptRoot "SmartScale.ps1"
if (Test-Path $pluginPath) {
    try {
        . $pluginPath
        $image = Optimize-ImageObject -Image $image
        Write-Host " OK ($($image.Width)x$($image.Height))" -ForegroundColor Green
    } catch {
        Write-Host " FAIL" -ForegroundColor Red
        Write-Host "  Error: $_"
        Write-Host "  >> SmartScale crashed. Image save will fail."
        exit 1
    }
} else {
    Write-Host " SKIP (not found at $pluginPath)" -ForegroundColor Yellow
}

# Step 6: Save to file
$testDir = Join-Path (Split-Path $PSScriptRoot -Parent) "temp"
if (-not (Test-Path $testDir)) { New-Item -ItemType Directory -Force -Path $testDir | Out-Null }
$testFile = Join-Path $testDir "diagnose_test.png"

Write-Host "[6/6] Save to $testFile..." -NoNewline
try {
    $image.Save($testFile, [System.Drawing.Imaging.ImageFormat]::Png)
    $image.Dispose()
    $size = (Get-Item $testFile).Length
    Write-Host " OK ($size bytes)" -ForegroundColor Green
    Write-Host "`n=== ALL CHECKS PASSED ===" -ForegroundColor Green
    Write-Host "File saved: $testFile"
    Write-Host "If this works but Alt+V doesn't, the issue is in the async PowerShell launch from AHK."
} catch {
    Write-Host " FAIL" -ForegroundColor Red
    Write-Host "  Error: $_"
    exit 1
}
