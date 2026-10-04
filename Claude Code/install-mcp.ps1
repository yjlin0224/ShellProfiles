# Run install-mcp.sh with Git Bash explicitly:
# Git\bin is not on PATH by default, and plain `bash` may resolve to WSL.
# Git for Windows records its install path in the registry (machine or per-user install).
$gitRoot = 'HKLM:\SOFTWARE\GitForWindows', 'HKCU:\SOFTWARE\GitForWindows' |
    ForEach-Object { (Get-ItemProperty $_ -ErrorAction SilentlyContinue).InstallPath } |
    Select-Object -First 1
$bash = Join-Path "$gitRoot" 'bin\bash.exe'
if (-not $gitRoot -or -not (Test-Path $bash)) {
    Write-Error "Git Bash not found: $bash"
    exit 1
}

# Always register in the default ~/.claude.json, ignoring any custom config dir.
# Restore it afterwards: a script run with `&` or `.\` shares the caller's environment.
$savedConfigDir = $env:CLAUDE_CONFIG_DIR
$env:CLAUDE_CONFIG_DIR = $null
try {
    & $bash (Join-Path $PSScriptRoot 'install-mcp.sh')
} finally {
    $env:CLAUDE_CONFIG_DIR = $savedConfigDir
}
exit $LASTEXITCODE
