# This is integration tests.

Import-Module $PSScriptRoot\..\ZLocation\ZLocation.psd1 -Force
# -Force re-import nested modules as well
Import-Module $PSScriptRoot\..\ZLocation\ZLocation.Storage.psm1 -Force
Import-Module $PSScriptRoot\..\ZLocation\ZLocation.Search.psm1 -Force

Describe 'ZLocation' {
   
    It 'can execute scenario with new directory' {
        try {
            $newdirectory = [guid]::NewGuid().Guid
            $curDirFullPath = ($pwd).Path
            mkdir $newdirectory
            cd $newdirectory
            $newDirFullPath = ($pwd).Path
            # trigger weight update
            prompt > $null
            # go somewhere else
            cd ~ 
            z ($newdirectory.Substring(0, 3))
            ($pwd).Path | Should Be $newDirFullPath

            $h = Get-ZLocation
            $h[$newDirFullPath] | Should Be 1
        }
        finally {
            cd $curDirFullPath
            rm -rec -force $newdirectory
            Remove-ZLocation $newDirFullPath
        }
    }
}