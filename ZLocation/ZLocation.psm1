Set-StrictMode -Version Latest

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

function Set-ZLocation()
{
    Register-PromptHook

    if (-not $args) {
        $args = @()
    }
    $matches = Find-Matches (Get-ZLocation) $args
    $pushDone = $false
    $matches | % {
        if (Test-path $_) {
            Push-Location ($_)
            $pushDone = $true
            break
        } else {
            Write-Warning "There is no path $_ on the file system. Removing obsolete date from datebase."
            Remove-ZLocation $_
        }
    } 
    if (-not $pushDone) {
        Write-Warning "Cannot find matching location"
    }
}

Register-PromptHook

Set-Alias -Name z -Value Set-ZLocation
Export-ModuleMember -Function Set-ZLocation, Get-ZLocation -Alias z
# export this function to make it accessible from prompt
Export-ModuleMember -Function Update-ZLocation
