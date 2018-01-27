Import-Module $PSScriptRoot\environment.psm1
Import-Module $PSScriptRoot\..\ZLocation\ZLocation.Search.psm1 -Force

Describe 'Find-Matches filters results correctly' {
    Context 'Equal weight' {
        if($IsWindows) {
            $foo3Path = 'C:\foo1\foo2\foo3'
            $foo2Path = 'C:\foo1\foo2'
            $foo1Path = 'C:\foo1'
            $rootPath = 'C:\'
            $data = @{
                'C:\foo1\foo2\foo3' = 1.0
                'C:\foo1\foo2' = 1.0
                'C:\foo1' = 1.0
                'C:\' = 1.0
            }
        } else {
            $foo3Path = '/foo1/foo2/foo3'
            $foo2Path = '/foo1/foo2'
            $foo1Path = '/foo1'
            $rootPath = '/'
            $data = @{
                '/foo1/foo2/foo3' = 1.0
                '/foo1/foo2' = 1.0
                '/foo1' = 1.0
                '/' = 1.0
            }
        }

        It 'Does not modify data' {
            Find-Matches $data fuuuu
            $data.Count | Should be 4
        }

        It 'returns only leave result' {
            Find-Matches $data foo2 | Should Be $foo2Path
        }

        It 'returns multiply results' {
            (Find-Matches $data foo | measure).Count | Should Be 3
        }

        It 'should be case-insensitive' {
            Find-Matches $data FoO1 | Should Be $foo1Path
        }

        if($Windows) {
            It 'returns disk root folder for C:' {
                Find-Matches $data C: | Should Be 'C:\'
            }

            It 'returns disk root folder for C' {
                Find-Matches $data C | Should Be 'C:\'
            }

        }

        It 'should ignore trailing \ or /' {
            Find-Matches $data "$foo1Path$PathSep" | Should Be $foo1Path
        }

    }

    Context 'Different weight' {
        if($IsWindows) {
            $adminPath = 'C:\admin'
            $data = @{
                'C:\admin' = 1.0
                'C:\admin\monad' = 2.0
            }
        } else {
            $adminPath = '/admin'
            $data = @{
                '/admin' = 1.0
                '/admin/monad' = 2.0
            }
        }

        It 'Use leaf matches' {
            Find-Matches $data 'adm' | Should Be $adminPath
        }
    }
}
