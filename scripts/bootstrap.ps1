param(
    [switch]$Build
)

Write-Host "Ensuring Go toolchain is available via winget..." -ForegroundColor Cyan
try {
    winget install --id GoLang.Go -e --silent --accept-source-agreements --accept-package-agreements
} catch {
    Write-Warning "winget install GoLang.Go failed: $_. Install Go manually before continuing."
}

Write-Host "Fetching Go dependencies..." -ForegroundColor Cyan
go mod tidy

if ($Build) {
    Write-Host "Building windoze-automation..." -ForegroundColor Cyan
    go build -o dist/windoze-automation.exe .
}
