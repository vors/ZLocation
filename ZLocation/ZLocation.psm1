param($Options = @{})
Set-StrictMode -Version Latest

# Listing nested modules in .psd1 creates additional scopes and Pester cannot mock cmdlets in those scopes.
# Instead we import them here which works.
Import-Module "$PSScriptRoot\ZLocation.Search.psm1"
Import-Module "$PSScriptRoot\ZLocation.Storage.psm1"

$RegisterAutomatically = $true
try {
    if($Options.Register -eq $false) { $RegisterAutomatically = $false }
} catch {}
write-host $RegisterAutomatically

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
    if(-not $RegisterAutomatically) { return }

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
if (Test-Path Function:\TabExpansion) {
    Rename-Item Function:\TabExpansion PreZTabExpansion
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

function global:TabExpansion($line, $lastWord) {
    switch -regex ($line) {
        $TabExpansionRegex {
        # "^(Set-ZLocation|z|j|pineapple) .*" {
            $arguments = $line -split ' ' | Where { $_.length -gt 0 } | select -Skip 1
            Find-Matches (Get-ZLocation) $arguments | Get-EscapedPath
        }
        default {
            if (Test-Path Function:\PreZTabExpansion) {
                PreZTabExpansion $line $lastWord
            }
        }
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

function Set-ZLocation()
{
    Register-PromptHook

    if (-not $args) {
        $args = @()
    }

    # Special case to enable Pop-Location.
    if (($args.Count -eq 1) -and ($args[0] -eq '-')) {
        Pop-ZLocation
        return
    }

    $matches = Find-Matches (Get-ZLocation) $args
    $pushDone = $false
    foreach ($match in $matches) {
        if (Test-path $match) {
            Push-Location $match
            $pushDone = $true
            break
        } else {
            Write-Warning "There is no path $match on the file system. Removing obsolete data from database."
            Remove-ZLocation $match
        }
    }
    if (-not $pushDone) {
        Write-Warning "Cannot find matching location"
    }
}

Register-PromptHook

Set-Alias -Name z -Value Set-ZLocation

# Create a list of aliases for Set-Zlocation, and add Set-Zlocation
$szlAliases = @(
    foreach ($alias in Get-Alias -Definition Set-ZLocation) {
        [regex]::Escape($alias.Name)
    }

    'Set-ZLocation'
)


# Make a regex to match starting a string with an alias followed by a space
$TabExpansionRegex = '^('+$($szlAliases -join '|')+') '

Export-ModuleMember -Function @('Set-ZLocation', 'Get-ZLocation', 'Pop-ZLocation', 'Remove-ZLocation') -Alias z
# export this function to make it accessible from prompt
Export-ModuleMember -Function Update-ZLocation
