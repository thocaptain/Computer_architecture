param(
    [string]$QuartusRoot = $env:QUARTUS_ROOTDIR,
    [switch]$CleanOnly
)

$ErrorActionPreference = 'Stop'
$ProjectName = 'DE2_115_single_cycle'
$ProjectDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$GeneratedOutputNames = @('db', 'incremental_db', 'output_files')

function Clear-QuartusOutputs {
    foreach ($Name in $GeneratedOutputNames) {
        $Path = Join-Path $ProjectDirectory $Name
        if (Test-Path -LiteralPath $Path) {
            Remove-Item -LiteralPath $Path -Recurse -Force
        }
    }
}

if ($CleanOnly) {
    Clear-QuartusOutputs
    Write-Host 'Removed prior Quartus-generated output directories.'
    return
}

if ([string]::IsNullOrWhiteSpace($QuartusRoot)) {
    $QuartusRoot = 'C:\altera\13.0sp1\quartus'
}

$QuartusSh = Join-Path $QuartusRoot 'bin64\quartus_sh.exe'
if (-not (Test-Path -LiteralPath $QuartusSh)) {
    throw "Quartus shell not found: $QuartusSh"
}

$BuildStarted = Get-Date
$BuildName = $BuildStarted.ToString('yyyyMMdd_HHmmss_fff')
$BuildRoot = Join-Path $ProjectDirectory 'builds'
$BuildDirectory = Join-Path $BuildRoot $BuildName
$ArchivedOutputDirectory = Join-Path $BuildDirectory 'output_files'
$LogPath = Join-Path $BuildDirectory 'compile.log'
$QsfText = Get-Content -LiteralPath (Join-Path $ProjectDirectory "$ProjectName.qsf") -Raw
$FamilyMatch = [regex]::Match($QsfText, '(?m)^set_global_assignment\s+-name\s+FAMILY\s+"([^"]+)"')
$DeviceMatch = [regex]::Match($QsfText, '(?m)^set_global_assignment\s+-name\s+DEVICE\s+(\S+)')
$ConfiguredFamily = if ($FamilyMatch.Success) { $FamilyMatch.Groups[1].Value } else { 'Unknown' }
$ConfiguredDevice = if ($DeviceMatch.Success) { $DeviceMatch.Groups[1].Value } else { 'Unknown' }

New-Item -ItemType Directory -Path $BuildDirectory -Force | Out-Null
foreach ($Name in @("$ProjectName.qpf", "$ProjectName.qsf", "$ProjectName.sdc")) {
    Copy-Item -LiteralPath (Join-Path $ProjectDirectory $Name) -Destination $BuildDirectory
}

$QuartusVersion = (& $QuartusSh --version 2>&1 | Out-String).Trim()
$BuildExitCode = 1
$BuildError = ''
$LocationPushed = $false

Clear-QuartusOutputs
try {
    Push-Location $ProjectDirectory
    $LocationPushed = $true
    & $QuartusSh --flow compile $ProjectName -c $ProjectName 2>&1 |
        Tee-Object -FilePath $LogPath
    $BuildExitCode = $LASTEXITCODE
}
catch {
    $BuildError = $_.Exception.Message
    $_ | Out-String | Add-Content -LiteralPath $LogPath
    $BuildExitCode = 1
}
finally {
    if ($LocationPushed) {
        Pop-Location
    }

    try {
        $CurrentOutputDirectory = Join-Path $ProjectDirectory 'output_files'
        if (Test-Path -LiteralPath $CurrentOutputDirectory) {
            New-Item -ItemType Directory -Path $ArchivedOutputDirectory -Force | Out-Null
            Copy-Item -Path (Join-Path $CurrentOutputDirectory '*') `
                -Destination $ArchivedOutputDirectory -Recurse -Force
        }
    }
    finally {
        Clear-QuartusOutputs
    }
}

$BuildEnded = Get-Date
$BuildStatus = if ($BuildExitCode -eq 0) { 'SUCCESS' } else { 'FAILED' }
$SofFiles = @(Get-ChildItem -Path $ArchivedOutputDirectory -Filter '*.sof' -Recurse -ErrorAction SilentlyContinue)
$SofInfo = if ($SofFiles.Count -gt 0) {
    ($SofFiles | ForEach-Object { "$($_.FullName) ($($_.Length) bytes)" }) -join [Environment]::NewLine
} else {
    'No .sof image was produced.'
}

@(
    "Build: $BuildName"
    "Started: $($BuildStarted.ToString('yyyy-MM-dd HH:mm:ss.fff zzz'))"
    "Finished: $($BuildEnded.ToString('yyyy-MM-dd HH:mm:ss.fff zzz'))"
    "Status: $BuildStatus"
    "Exit code: $BuildExitCode"
    "Quartus: $($QuartusVersion -replace '\s+', ' ')"
    "Project: $ProjectName"
    'Top: TOP_SINGLE_CYCLE_DE2_115'
    "Family: $ConfiguredFamily"
    "Device: $ConfiguredDevice"
    "Image: $SofInfo"
    "Error: $BuildError"
) | Set-Content -LiteralPath (Join-Path $BuildDirectory 'build-info.txt') -Encoding UTF8

Write-Host "Build archive: $BuildDirectory"
Write-Host "Status: $BuildStatus"
if ($BuildExitCode -ne 0) {
    exit $BuildExitCode
}
