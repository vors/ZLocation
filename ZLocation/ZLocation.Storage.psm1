Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'ZLocation.Service.psd1')
Import-Module (Join-Path $PSScriptRoot 'ZLocation.Search.psm1')

function Get-ZLocation($Match)
{
    $hash = [Collections.HashTable]::new()
    foreach ($item in (Get-ZDBLocation))
    {
        $hash.add($item.path, $item.weight)
    }

    if ($Match)
    {
        # Create a new hash containing only matching locations
        $newhash = @{}
        $Match | %{Find-Matches $hash $_} | %{$newhash.add($_, $hash[$_])}
        $hash = $newhash
    }

    return $hash
}

function Add-ZWeight {
    param (
        [Parameter(Mandatory=$true)] [string]$Path,
        [Parameter(Mandatory=$true)] [double]$Weight
    )
    Update-ZDBLocation $path $weight
}

function Remove-ZLocation {
    param (
        [Parameter(Mandatory=$true)] [string]$Path
    )
    Remove-ZDBLocation $path
}

Export-ModuleMember -Function @("Get-ZLocation", "Add-ZWeight", "Remove-ZLocation")
