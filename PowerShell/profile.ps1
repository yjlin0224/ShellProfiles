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

# Run a command from $WorkDirectory instead of $HOME when invoked at ~ (and return after).
function Invoke-OutsideHome {
    param(
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [string] $WorkDirectory,
        [object[]] $Arguments
    )
    $command = Get-Command $Name -CommandType ExternalScript, Application | Select-Object -First 1
    $atHome = (Get-Location).ProviderPath.TrimEnd("\") -eq $HOME.TrimEnd("\")
    if ($atHome) {
        New-Item -ItemType Directory -Path $WorkDirectory -Force | Out-Null
        Push-Location $WorkDirectory
    }
    try { & $command @Arguments }
    finally { if ($atHome) { Pop-Location } }
}

# Claude Code never persists workspace trust for $HOME, so the trust dialog
# appears on every launch from ~. Launch ccs/claude from ~\claude instead.
$ClaudeWorkDirectory = Join-Path $HOME "claude"
function ccs { Invoke-OutsideHome -Name ccs -WorkDirectory $ClaudeWorkDirectory -Arguments $args }
function claude { Invoke-OutsideHome -Name claude -WorkDirectory $ClaudeWorkDirectory -Arguments $args }

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
