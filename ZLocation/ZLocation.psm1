Set-StrictMode -Version Latest

# Listing nested modules in .psd1 create additional scopes so pester cannot moke cmdlets in them.
# We use direct Import-Module instead.
Import-Module "$PSScriptRoot\ZLocation.Search.psm1"
Import-Module "$PSScriptRoot\ZLocation.Storage.psm1"

# I currently consider number of commands executed in directory a better metric, then total time spent in directory.
# See [corresponding issue](https://github.com/vors/ZLocation/issues/6) for details.
# If you prefer old behavior, uncomment this code.
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

    # populate folder immidiatly after the first cd
    Add-ZWeight $path 0
}

# this approach hurts `cd` performance (0.0008 sec vs 0.025 sec). 
# Consider replace it with OnIdle Event.
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
# Tab complention.
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
        "^(Set-ZLocation|z) .*" {
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
            Write-Warning "There is no path $match on the file system. Removing obsolete date from datebase."
            Remove-ZLocation $match
        }
    } 
    if (-not $pushDone) {
        Write-Warning "Cannot find matching location"
    }
}

Register-PromptHook

Set-Alias -Name z -Value Set-ZLocation
Export-ModuleMember -Function @('Set-ZLocation', 'Get-ZLocation', 'Pop-ZLocation', 'Remove-ZLocation') -Alias z
# export this function to make it accessible from prompt
Export-ModuleMember -Function Update-ZLocation
