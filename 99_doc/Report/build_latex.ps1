$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    for ($Pass = 1; $Pass -le 2; $Pass++) {
        # MiKTeX can emit update notices on stderr even after a successful build.
        $ErrorActionPreference = 'Continue'
        & xelatex --disable-installer -interaction=nonstopmode -halt-on-error Milestone1_Report.tex
        $CompileExit = $LASTEXITCODE
        $ErrorActionPreference = 'Stop'
        if ($CompileExit -ne 0) { throw 'LaTeX compilation failed; see Milestone1_Report.log.' }
    }
} finally { Pop-Location }
