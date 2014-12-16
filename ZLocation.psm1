Set-StrictMode -Version Latest

#
# You can customize this logic to tweak weight function.
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
}

# this approach hurts `cd` performance (0.0008 sec vs 0.025 sec). 
# Consider replace it with OnIdle Event.
(Get-Variable pwd).attributes.Add((new-object ValidateScript { Update-ZLocation $_.Path; return $true }))
#
# End of weight function logic.
#


#
# Querying logic. You can customize it.
#
function Find-Matches([hashtable]$hash, [string[]]$query)
{
    foreach ($key in ($hash.GetEnumerator() | %{$_.Name})) 
    {
        if (-not (Test-FuzzyMatch $key $query)) 
        {
            $hash.Remove($key)
        }
    }
    $res = $hash.GetEnumerator() | sort -Property Value -Descending
    if ($res) {
        $res | %{$_.Name}
    }
}

function Test-FuzzyMatch([string]$path, [string[]]$query)
{
    if ($query -eq $null) {
        return $true
    }
    $n = $query.Length
    if ($n -eq 0)
    {
        # empty query match to everything
        return $true
    }

    for ($i=0; $i -lt $n-1; $i++)
    {
        if (-not ($path -match $query[$i]))
        {
            return $false
        }
    }   
    
    # after tab expansion, we get desired full path as a last query element.
    if ([System.IO.Path]::IsPathRooted($query[$n-1])) 
    {
        return $path -eq $query[$n-1]
    }

    $leaf = Split-Path -Leaf $path
    return ($leaf -match $query[$n-1]) 
}
#
# End of querying logic.
#

function Set-ZLocation()
{
    if (-not $args) {
        $args = @()
    }
    $matches = Find-Matches (Get-ZLocation) $args
    if ($matches) {
        Push-Location ($matches | Select-Object -First 1)
    } else {
        Write-Warning "Cannot find matching location"
    }
}


#
# Tab complention
#
if (Test-Path Function:\TabExpansion) {
    Rename-Item Function:\TabExpansion PreZTabExpansion
}

function global:TabExpansion($line, $lastWord) {
    switch -regex ($line) {
        "^(Set-ZLocation|z) .*" {
            $arguments = $line -split ' ' | Where { $_.length -gt 0 } | select -Skip 1
            Find-Matches (Get-ZLocation) $arguments
        }
        default {
            if (Test-Path Function:\PreZTabExpansion) {
                PreZTabExpansion $line $lastWord
            }
        }
    }
}
#
# End of tab completion
#

Set-Alias -Name z -Value Set-ZLocation

Export-ModuleMember -Function Set-ZLocation, Get-ZLocation -Alias z