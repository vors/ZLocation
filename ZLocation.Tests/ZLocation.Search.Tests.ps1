Import-Module $PSScriptRoot\..\ZLocation\ZLocation.Search.psm1 -Force

if($IsWindows -eq $null) {
    $IsWindows = $true
}

Describe 'Find-Matches filters results correctly' {
    Context 'Equal weight' {
        if($IsWindows) {
            $data = @{
                'C:\foo1\foo2\foo3' = 1.0
                'C:\foo1\foo2' = 1.0
                'C:\foo1' = 1.0
                'C:\' = 1.0
            }
            $rootPath = 'C:\'
            $foo1Path = 'C:\foo1'
            $foo2Path = 'C:\foo1\foo2'
            $foo3Path = 'C:\foo1\foo2\foo3'
            $pathSep = '\'
        } else {
            $data = @{
                '/foo1/foo2/foo3' = 1.0
                '/foo1/foo2' = 1.0
                '/foo1' = 1.0
                '/' = 1.0
            }
            $rootPath = '/'
            $foo1Path = '/foo1'
            $foo2Path = '/foo1/foo2'
            $foo3Path = '/foo1/foo2/foo3'
            $pathSep = '/'
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

        If($IsWindows) {
            It 'returns disk root folder for C:' {
                Find-Matches $data C: | Should Be $rootPath
            }

            It 'returns disk root folder for C' {
                Find-Matches $data C | Should Be $rootPath
            }
        } else {
            It 'returns disk root folder for /' {
                Find-Matches $data / | Should Be $rootPath
            }
        }

        It "should ignore trailing $pathSep" {
            Find-Matches $data "$foo1Path$pathSep" | Should Be $foo1Path
        }

    }

    Context 'Different weight' {
        if($IsWindows) {
            $data = @{
                'C:\admin' = 1.0
                'C:\admin\monad' = 2.0
            }
            $adminPath = 'C:\admin'
        } else {
            $data = @{
                '/admin' = 1.0
                '/admin/monad' = 2.0
            }
            $adminPath = '/admin'
        }

        It 'Uses leaf match' {
            Find-Matches $data 'adm' | Should Be $adminPath
        }
    }

    Context 'Prefer prefix over weight' {
        if($IsWindows) {
            $fooPath = 'C:\foo'
            $afooPath = 'C:\afoo'
        } else {
            $fooPath = '/foo'
            $afooPath = '/afoo'
        }
        $data = @{
            $fooPath = 1.0
            $afooPath = 1000.0
        }

        It 'Uses prefix match' {
            Find-Matches $data 'fo' | Should Be @($fooPath, $afooPath)
        }
    }

    Context 'Prefer exact match over weight and prefix' {
        if($IsWindows) {
            $fooPath = 'C:\foo'
            $afooPath = 'C:\foo2'
        } else {
            $fooPath = '/foo'
            $afooPath = '/foo2'
        }
        $data = @{
            $fooPath = 1.0
            $afooPath = 1000.0
        }

        It 'Uses prefix match' {
            Find-Matches $data 'foo' | Should Be @($fooPath, $afooPath)
        }
    }
}
