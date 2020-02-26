Set-StrictMode -Version Latest

# Listing nested modules in .psd1 creates additional scopes and Pester cannot mock cmdlets in those scopes.
# Instead we import them here which works.
Import-Module "$PSScriptRoot\ZLocation.Service.psd1"
Import-Module "$PSScriptRoot\ZLocation.Search.psm1"
Import-Module "$PSScriptRoot\ZLocation.Storage.psm1"

# I currently consider number of commands executed in directory to be a better metric, than total time spent in a directory.
# See [corresponding issue](https://github.com/vors/ZLocation/issues/6) for details.
# If you prefer the old behavior, uncomment this code.
<#
#
# Weight function.
#
function Update-ZLocation([string]$path)
{
    $now = [datetime]::Now
    if (Test-Path variable:global:__zlocation_current)
    {
        $prev = $global:__zlocation_current
        $weight = $now.Subtract($prev.Time).TotalSeconds
        Add-ZWeight ($prev.Location) $weight
    }

    $global:__zlocation_current = @{
        Location = $path
        Time = [datetime]::Now
    }

    # populate folder immediately after the first cd
    Add-ZWeight $path 0
}

# this approach hurts `cd` performance (0.0008 sec vs 0.025 sec).
# Consider replacing it with OnIdle Event.
(Get-Variable pwd).attributes.Add((new-object ValidateScript { Update-ZLocation $_.Path; return $true }))
#>

function Update-ZLocation
{
    param (
        [Parameter(Mandatory=$true)] [string]$Path
    )
    Add-ZWeight $path 1.0
}

function Register-PromptHook
{
    param()

    # Insert a call to Update-Zlocation in the prompt function but only once.
    if (-not (Test-Path function:\global:ZlocationOrigPrompt)) {
        Copy-Item function:\prompt function:\global:ZlocationOrigPrompt
        $global:ZLocationPromptScriptBlock = {
            Update-ZLocation $pwd
            ZLocationOrigPrompt
        }

        Set-Content -Path function:\prompt -Value $global:ZLocationPromptScriptBlock -Force
    }
}

# On removal/unload of the module, restore original prompt or LocationChangedAction event handler.
$ExecutionContext.SessionState.Module.OnRemove = {
    Copy-Item function:\global:ZlocationOrigPrompt function:\global:prompt
    Remove-Item function:\ZlocationOrigPrompt
    Remove-Variable ZLocationPromptScriptBlock -Scope Global
}

#
# End of weight function.
#


#
# Tab completion.
#
if(Get-Command -Name Register-ArgumentCompleter -ErrorAction Ignore) {
    'Set-ZLocation', 'Invoke-ZLocation' | % {
        Register-ArgumentCompleter -CommandName $_ -ParameterName match -ScriptBlock {
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)
            # Omit first item (command name) and empty strings
            $i = $commandAst.CommandElements.Count
            [string[]]$query = if($i -gt 1) {
                $commandAst.CommandElements[1..($i-1)] | ForEach-Object { $_.toString()}
            }
            Find-Matches (Get-ZLocation) $query | Get-EscapedPath
        }
    }
}

function Get-EscapedPath
{
    param(
    [Parameter(
        Position=0,
        Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)
    ]
    [string]$path
    )

    process {
        if ($path.Contains(' '))
        {
            return '"' + $path + '"'
        }
        return $path
    }
}

#
# End of tab completion.
#

# Default location stack is local for module. Users cannot use 'Pop-Location' directly, so we need to provide a command inside the module for that.
function Pop-ZLocation
{
    Pop-Location
}

function Set-ZLocation([Parameter(ValueFromRemainingArguments)][string[]]$match)
{
    Register-PromptHook

    if (-not $match) {
        $match= @()
    }

    # Special case to enable Pop-Location.
    if (($match.Count -eq 1) -and ($match[0] -eq '-')) {
        Pop-ZLocation
        return
    }

    $matches = Find-Matches (Get-ZLocation) $match
    $pushDone = $false
    foreach ($m in $matches) {
        if (Test-path $m) {
            Push-Location $m
            $pushDone = $true
            break
        } else {
            Write-Warning "There is no path $m on the file system. Removing obsolete data from database."
            Remove-ZLocation $m
        }
    }
    if (-not $pushDone) {
        if (($match.Count -eq 1) -and (Test-Path "$match")) {
            Write-Debug "No matches for $match, attempting Push-Location"
            Push-Location "$match"
        } else {
            Write-Warning "Cannot find matching location"
        }
    }
}

<#
    .SYNOPSIS
    Jump to popular directories.

    .DESCRIPTION
    This is the main entry point in the interactive usage of ZLocation.
    It's intended to be used as an alias z.

    Usage:
        z - prints available directories
        z -l foo - prints available directories scoped to foo query
        z foo - jumps into the location that matches foo
        z foo <TAB> - pressing tab cycles through different matches for foo
        z - - undos the last z jump.

    .EXAMPLE
    PS>z
    Weight Path
    ------ ----
        7 C:\Windows
        1 C:\Windows\System
        27 C:\WINDOWS\system32
        [...]

    .EXAMPLE
    C:\>z foo
    C:\foo>

    .EXAMPLE
    C:\>z foo <PRESS TAB; NOT ENTER>
    C:\>z C:\foo <PRESS TAB AGAIN>
    C:\>z C:\another_less_popular\foo <PRESS TAB AGAIN>
    C:\>z C:\least_popular\foo
    C:\least_popular\foo>

    .EXAMPLE
    PS>z -l sys
    Weight Path
    ------ ----
        27 C:\WINDOWS\system32
         1 C:\Windows\System

    .EXAMPLE
    C:\>z foo
    C:\foo>z bar
    C:\baz\bar> z -
    C:\foo>z -
    C:\>z -
    C:\>#no-op

    .LINK
    https://github.com/vors/ZLocation
#>
function Invoke-ZLocation
{
    param(
        [Parameter(ValueFromRemainingArguments)][string[]]$match
    )

    $sortProperty = "Path"
    $sortDescending = $false

    $locations = $null
    if ($null -eq $match) {
        $locations = Get-ZLocation
    }
    elseif (($match.Length -gt 0) -and ($match[0] -eq '-l')) {
        $locations = Get-ZLocation ($match | Select-Object -Skip 1)
        $sortProperty = "Weight"
        $sortDescending = $true
    }

    if ($locations) {
        $locations |
            ForEach-Object {$_.GetEnumerator()} |
            ForEach-Object {[PSCustomObject]@{Weight = $_.Value; Path = $_.Name}} |
            Sort-Object -Property $sortProperty -Descending:$sortDescending
        return
    }

    Set-ZLocation -match $match
}

function Get-FrequentFolders {
    If (((Get-Variable IsWindows -ErrorAction Ignore | Select-Object -ExpandProperty Value) -or 
    $PSVersionTable.PSVersion.Major -lt 6) -and ([environment]::OSVersion.Version.Major -ge 10)) {
        if (-not $ExecutionContext.SessionState.LanguageMode -eq 'ConstrainedLanguage') {
            $QuickAccess = New-Object -ComObject shell.application
            $QuickAccess.Namespace("shell:::{679f85cb-0220-4080-b29b-5540cc05aab6}").Items() |
                Where-Object IsFolder |
                Select-Object -ExpandProperty Path
        }
    }
}

Get-FrequentFolders | ForEach-Object {Add-ZWeight -Path $_ -Weight 0}

Register-PromptHook

Set-Alias -Name z -Value Invoke-ZLocation

Export-ModuleMember -Function @('Invoke-ZLocation', 'Set-ZLocation', 'Get-ZLocation', 'Pop-ZLocation', 'Remove-ZLocation') -Alias z
# export this function to make it accessible from prompt
Export-ModuleMember -Function Update-ZLocation
