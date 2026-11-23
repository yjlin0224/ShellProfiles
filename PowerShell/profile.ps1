(Get-Host).PrivateData.FormatAccentColor = [System.ConsoleColor]::Magenta
(Get-Host).PrivateData.ErrorAccentColor = [System.ConsoleColor]::Cyan
(Get-Host).PrivateData.ErrorForegroundColor = [System.ConsoleColor]::Red
(Get-Host).PrivateData.ErrorBackgroundColor = [System.ConsoleColor]::Black
(Get-Host).PrivateData.WarningForegroundColor = [System.ConsoleColor]::Yellow
(Get-Host).PrivateData.WarningBackgroundColor = [System.ConsoleColor]::Black
(Get-Host).PrivateData.DebugForegroundColor = [System.ConsoleColor]::Green
(Get-Host).PrivateData.DebugBackgroundColor = [System.ConsoleColor]::Black
(Get-Host).PrivateData.VerboseForegroundColor = [System.ConsoleColor]::Blue
(Get-Host).PrivateData.VerboseBackgroundColor = [System.ConsoleColor]::Black
(Get-Host).PrivateData.ProgressForegroundColor = [System.ConsoleColor]::Gray
(Get-Host).PrivateData.ProgressBackgroundColor = [System.ConsoleColor]::Black

Set-PSReadLineOption -Colors @{
    "Error"     = [System.ConsoleColor]::Red
    "Default"   = [System.ConsoleColor]::White
    "Comment"   = [System.ConsoleColor]::DarkGreen
    "Keyword"   = [System.ConsoleColor]::DarkMagenta
    "String"    = [System.ConsoleColor]::Blue
    "Operator"  = [System.ConsoleColor]::Gray
    "Variable"  = [System.ConsoleColor]::Cyan
    "Command"   = [System.ConsoleColor]::Yellow
    "Parameter" = [System.ConsoleColor]::DarkCyan
    "Type"      = [System.ConsoleColor]::DarkBlue
    "Number"    = [System.ConsoleColor]::Magenta
    "Member"    = [System.ConsoleColor]::DarkYellow
}

function Prompt {
    $CurrentPath = $ExecutionContext.SessionState.Path.CurrentLocation.Path
    $RelativePath = [System.IO.Path]::GetRelativePath($Home, $CurrentPath)
    if ($RelativePath -eq ".") {
        $Path = "~"
    }
    elseif ($CurrentPath.IndexOf($Home) -eq 0) {
        $Path = Join-Path "~" $RelativePath
    }
    else {
        $Path = $CurrentPath
    }
    if ($Path.EndsWith("\")) {
        $Path = $Path.TrimEnd("\")
    }
    if ($Path.IndexOf("Microsoft.PowerShell.Core\FileSystem::") -eq 0) {
        $Path = $Path.Remove(0, "Microsoft.PowerShell.Core\FileSystem::".Length)
    }
    $Authority = "$($Env:UserName)@$([System.Net.Dns]::GetHostName())"
    $Host.UI.RawUI.WindowTitle = "$($Authority):$($Path) - PowerShell"
    Write-Host $Authority -NoNewLine -ForegroundColor Green
    Write-Host ":" -NoNewLine -ForegroundColor DarkGray
    Write-Host $Path
    return "$(">" * ($NestedPromptLevel + 1)) "
}

function Set-LastWriteTime {
    $FilePath = $Args[0]
    if ($null -eq $FilePath) {
        return
    }
    if (Test-Path $FilePath) {
        (Get-ChildItem $FilePath).LastWriteTime = Get-Date
    }
    else {
        New-Item $FilePath
    }
}

# Get-ClaudeStartDirectory returns the directory to start ccs/claude from, or $null to stay in
# the current directory:
# 1. At ~ itself, start from ~\claude. Claude Code never persists workspace trust for $HOME, so
#    the trust dialog would appear on every launch from ~. This rule comes first because ~ has
#    no .git.
# 2. Inside a git work tree, start from its top-level directory, so the session belongs to the
#    repository.
# 3. Outside git, inside a src or apps folder under the projects root, start from the directory
#    that holds the first such folder: <root>\a\src\b and <root>\a\src both start from <root>\a.
# The projects root is $Env:PROJECTS_ROOT, or D:\Projects when the variable isn't set.
$ClaudeWorkDirectory = Join-Path $HOME "claude"
$ProjectsRoot = if ($Env:PROJECTS_ROOT) { $Env:PROJECTS_ROOT.TrimEnd("\") } else { "D:\Projects" }
function Get-ClaudeStartDirectory {
    $current = (Get-Location).ProviderPath.TrimEnd("\")
    if ($current -eq $HOME.TrimEnd("\")) {
        return $ClaudeWorkDirectory
    }
    if (Get-Command git -CommandType Application -ErrorAction SilentlyContinue) {
        $topLevel = git -C $current rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -eq 0 -and $topLevel) {
            # git prints the path with forward slashes
            $topLevel = [System.IO.Path]::GetFullPath($topLevel).TrimEnd("\")
            if ($topLevel -eq $current) {
                return $null
            }
            return $topLevel
        }
    }
    if (-not $current.StartsWith("$ProjectsRoot\", [System.StringComparison]::OrdinalIgnoreCase)) {
        return $null
    }
    $start = $ProjectsRoot
    foreach ($segment in $current.Substring($ProjectsRoot.Length + 1).Split("\")) {
        if ($segment -in "src", "apps") {
            return $start
        }
        $start = Join-Path $start $segment
    }
    return $null
}

# Run ccs or claude from Get-ClaudeStartDirectory, and return to the current directory after.
function Invoke-Claude {
    param(
        [Parameter(Mandatory)] [string] $Name,
        [object[]] $Arguments
    )
    $command = Get-Command $Name -CommandType ExternalScript, Application | Select-Object -First 1
    $start = Get-ClaudeStartDirectory
    if ($start) {
        New-Item -ItemType Directory -Path $start -Force | Out-Null
        Write-Host "Starting $Name in $start" -ForegroundColor DarkGray
        Push-Location $start
    }
    try { & $command @Arguments }
    finally { if ($start) { Pop-Location } }
}

function ccs { Invoke-Claude -Name ccs -Arguments $args }
function claude { Invoke-Claude -Name claude -Arguments $args }

Set-Alias touch Set-LastWriteTime

& {
    $WindowsInfomation = & "~\Get-WindowsInfomation.ps1"
    $Infomation = "PowerShell $($PSVersionTable.PSVersion) [$($WindowsInfomation)]"
    $Copyright = "Copyright © Microsoft Corporation. All rights reserved."

    chcp 65001 | Out-Null

    Write-Host $Infomation -ForegroundColor Green
    Write-Host $Copyright -ForegroundColor DarkGray
    Write-Host
}
