Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'ZLocation.Service.psd1')
Import-Module (Join-Path $PSScriptRoot 'ZLocation.Search.psm1')

function Get-ZLocation($Match)
{
    $service = Get-ZService
    $hash = [Collections.HashTable]::new()
    foreach ($item in $service.Get())
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

function Add-ZWeight([string]$path, [double]$weight) {
    $service = Get-ZService
    $service.Add($path, $weight)
}

function Remove-ZLocation([string]$path) {
    $service = Get-ZService
    $service.Remove($path)
}

$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
    Write-Warning "[ZLocation] module was removed, but service was not closed."
}

Export-ModuleMember -Function @("Get-ZLocation", "Add-ZWeight", "Remove-ZLocation")
