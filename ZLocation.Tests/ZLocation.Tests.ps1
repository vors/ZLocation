# Integration tests.

# Maybe -Force re-import nested modules too?
#Import-Module $PSScriptRoot\..\ZLocation\ZLocation.Storage.psm1 -Force
#Import-Module $PSScriptRoot\..\ZLocation\ZLocation.Search.psm1 -Force
Import-Module $PSScriptRoot\..\ZLocation\ZLocation.psd1 -Force

. "$PSScriptRoot/_mocks.ps1"

Describe 'ZLocation' {

    Context 'Success scenario' {

        It 'can execute scenario with new directory' {
            try {
                $newdirectory = [guid]::NewGuid().Guid
                $curDirFullPath = ($pwd).Path
                mkdir $newdirectory
                cd $newdirectory
                $newDirFullPath = ($pwd).Path
                # trigger weight update
                prompt > $null
                # go back
                cd $curDirFullPath

                # do the jump
                z ($newdirectory.Substring(0, 3))
                ($pwd).Path | Should Be $newDirFullPath

                # verify that pop-location can be used after z
                z -
                ($pwd).Path | Should Be $curDirFullPath

                $h = Get-ZLocation
                $h[$newDirFullPath] | Should Be 1
            } finally {
                cd $curDirFullPath
                Remove-Item -rec -force $newdirectory
                Remove-ZLocation $newDirFullPath
            }
        }

        It 'can navigate to an unvisited directory' {
            try {
                $newdirectory = [guid]::NewGuid().Guid
                $curDirFullPath = ($pwd).Path
                mkdir $newdirectory
                $newDirFullPath = Join-Path $curDirFullPath $newdirectory

                # do the jump
                z $newdirectory
                ($pwd).Path | Should Be $newDirFullPath
            }
            finally {
                cd $curDirFullPath
                Remove-Item -rec -force $newdirectory
                Remove-ZLocation $newDirFullPath
            }
        }
    }

    Context 'tab completion' {
        Function Complete($command) {
            [System.Management.Automation.CommandCompletion]::CompleteInput($command, $command.Length, @{}).CompletionMatches.ListItemText
            (TabExpansion2 $command $command.Length).CompletionMatches.ListItemText
        }
        BeforeEach {
            Update-ZLocation 'prefixABC'
            Update-ZLocation 'prefixDEF'
            Update-ZLocation 'notthisGHI'
            Update-ZLocation 'notthisJKL'
        }
        AfterEach {
            Remove-ZLocation -path 'prefixABC'
            Remove-ZLocation -path 'prefixDEF'
            Remove-ZLocation -path 'notthisGHI'
            Remove-ZLocation -path 'notthisJKL'
        }
        It 'should offer only completions matching entered text' {
            $completions = Complete 'z refix'
            $completions | Should -Contain 'prefixABC'
            $completions | Should -Contain 'prefixDEF'
            $completions | Should -Not -Contain 'notthisGHI'
            $completions | Should -Not -Contain 'notthisJKL'
        }
        It 'should offer all completions when invoked without prefix' {
            $completions = Complete 'z '
            $completions | Should -Contain 'prefixABC'
            $completions | Should -Contain 'prefixDEF'
            $completions | Should -Contain 'notthisGHI'
            $completions | Should -Contain 'notthisJKL'
        }
    }
}
