$ErrorActionPreference = 'stop'
Set-StrictMode -Version latest

$RepoRoot = (Resolve-Path $PSScriptRoot\..).Path

Describe 'Text files formatting' {
    
    $allTextFiles = ls $RepoRoot -Exclude dependencies | % {
        ls -file -recurse $_
    }
    
    Context 'Files encoding' {

        It "Doesn't use Unicode encoding" {
            $allTextFiles | %{
                $path = $_.FullName
                $bytes = [System.IO.File]::ReadAllBytes($path)
                $zeroBytes = @($bytes -eq 0)
                if ($zeroBytes.Length) {
                    Write-Warning "File $($_.FullName) contains 0 bytes. It's probably uses Unicode and need to be converted to UTF-8"
                }
                $zeroBytes.Length | Should Be 0
            }
        }
    }

    Context 'Indentations' {

        It "We are using spaces for indentaion, not tabs" {
            $totalTabsCount = 0
            $allTextFiles | %{
                $fileName = $_.FullName
                cat $_.FullName -Raw | Select-String "`t" | % {
                    Write-Warning "There are tab in $fileName"
                    $totalTabsCount++
                }
            }
            $totalTabsCount | Should Be 0
        }
    }
}

Describe 'Version consistency' {

    It 'uses consistent version in ZLocation.psd1 and appveyor.yml' {
        # TODO: can we use some yml parser for that?
        $ymlVersionLine = cat $RepoRoot\appveyor.yml | ? {$_ -like 'version: *'} | Select -first 1
        # i.e. $ymlVersionLine = 'version: 1.7.0.{build}'
        $ymlVersionLine | Should Not BeNullOrEmpty
        
        $manifest = (cat $RepoRoot\ZLocation\ZLocation.psd1 -Raw) | iex
        "version: $($manifest.ModuleVersion).{build}" | Should be $ymlVersionLine
    }
}
