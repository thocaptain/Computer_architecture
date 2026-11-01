param([string]$QuartusRoot = 'C:\intelFPGA_lite\18.1\quartus')
$ErrorActionPreference = 'Stop'
$ProjectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = (Resolve-Path (Join-Path $ProjectDir '../../../..')).Path
Push-Location $Root
try {
    # run_app06 prepares the firmware/project and must pass simulation first.
    & wsl.exe bash 10_sim/run_app06.sh
    if ($LASTEXITCODE -ne 0) { throw 'App06 simulation/build failed' }
    Push-Location $ProjectDir
    try {
        & (Join-Path $QuartusRoot 'bin64/quartus_sh.exe') --flow compile app06 2>&1 |
            Tee-Object -FilePath compile.log
        if ($LASTEXITCODE -ne 0) { throw 'Quartus compile failed; see compile.log' }
    } finally { Pop-Location }
} finally { Pop-Location }
