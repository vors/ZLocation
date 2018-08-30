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

function Update-ZLocation([string]$path)
{
    Add-ZWeight $path 1.0
}

function Register-PromptHook
{
    param()

    $oldPrompt = Get-Content function:\prompt
    if( $oldPrompt -notlike '*Update-ZLocation*' )
    {
        $newPrompt = @'
Update-ZLocation $pwd

'@
        $newPrompt += $oldPrompt
        $function:prompt = [ScriptBlock]::Create($newPrompt)
    }
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
        Write-Warning "Cannot find matching location"
    }
}

<#
    This is the main entry point in the interactive usage of ZLocation.
    It's intended to be used as an alias z

    Usage:
        z - prints available directories
        z -l foo - prints available directories scoped to foo query
        z foo - jumps into the location that matches foo
#>
function Invoke-ZLocation
{
    param(
        [Parameter(ValueFromRemainingArguments)][string[]]$match
    )

    if ($match -eq $null) {
        Get-ZLocation
        return
    }

    if ($match.Length -gt 0 -and $match[0] -eq '-l') {
        Get-ZLocation ($match | Select-Object -Skip 1)
        return
    }

    Set-ZLocation $match
}

Register-PromptHook

Set-Alias -Name z -Value Invoke-ZLocation

Export-ModuleMember -Function @('Invoke-ZLocation', 'Set-ZLocation', 'Get-ZLocation', 'Pop-ZLocation', 'Remove-ZLocation') -Alias z
# export this function to make it accessible from prompt
Export-ModuleMember -Function Update-ZLocation
