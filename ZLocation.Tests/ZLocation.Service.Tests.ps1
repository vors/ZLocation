Describe 'ZLocation.Service' {
    Import-Module $PSScriptRoot\..\ZLocation\ZLocation.Service.psd1 -Force
    . "$PSScriptRoot/_mocks.ps1"

    Context 'Testing database init' {
        InModuleScope ZLocation.Service {
            $dbpath = Get-ZLocationDatabaseFilePath
            $testdbpattern = '*z-location-tests.db'
            if ($dbpath -notlike $testdbpattern) {throw 'Not using test database, aborting tests'}
            if (-not (Test-ZLocationDBUnlocked)) {throw 'Database is locked, aborting tests'}

            # It 'Is referring to test DB' {
            #     $dbpath | Should -BeLike $testdbpattern
            # }

            It 'Initializes a database' {
                if (Test-Path ($dbpath)) {Remove-Item $dbpath}

                Initialize-ZLocationDB
                Assert-MockCalled Get-ZLocationDatabaseFilePath  
                Test-Path $dbpath | Should -Be $true
            }
        }
    }

    Context 'Testing database functionality' {
        InModuleScope ZLocation.Service {
            $dbpath = Get-ZLocationDatabaseFilePath
            $testdbpattern = '*z-location-tests.db'
            if ($dbpath -notlike $testdbpattern) {throw 'Not using test database, aborting tests'}
            if (-not (Test-ZLocationDBUnlocked)) {throw 'Database is locked, aborting tests'}

            BeforeEach {
                if (Test-Path $dbpath) {Remove-Item $dbpath}
                Initialize-ZLocationDB
            }

            $path = [guid]::NewGuid().Guid 

            It 'Adds and retrieves a location' {
                Update-ZDBLocation -Path $path
                Get-ZDBLocation | Should -HaveCount 1
                $l = [Location]::new()
                $l.path = $path
                $l.weight = 1
                Get-ZDBLocation | Select-Object -First 1 | ConvertTo-Json | Should -Be ($l | ConvertTo-Json)
            }

            It 'Adds and removes a location' {
                Update-ZDBLocation -Path $path
                Remove-ZDBLocation $path
                Get-ZDBLocation | Should -BeNullOrEmpty
            }
        }
    }

    # Context "Malformed DB entries" {
    #     try {
    #         # Connect to the database and add some malformed entries
    #         Add-Type -Path $PSScriptRoot\..\ZLocation\LiteDB\LiteDB.dll
    #         $connectionString = "Filename=$($testDb); Mode=Shared"
    #         $db = [LiteDB.LiteDatabase]::new($connectionString)
    #         $collection = $db.GetCollection('Location')
    #         $oidquery = [LiteDB.Query]::Where('_id',{$args -like '{"$oid":"*"}'})
            
    #         # Create and insert a malformed location
    #         $bsondocument = [LiteDB.BsonDocument]::new()
    #         $bsondocument['weight'] = 1234
    #         $collection.Insert($bsondocument)

    #         It "confirms malformed entries inserted" {
    #             # This actually tests the query more than anything.
    #             $malformedEntries = (,$collection.Find($oidquery))
    #             $malformedEntries | Should -HaveCount 1
    #         }

    #         It "can remove malformed location entries" {
    #             # Ensure nothing else can be connecting to $db to placate AppVeyor.
    #             $db.Dispose()
    #             Get-ZDBLocation
    #             $db = [LiteDB.LiteDatabase]::new($connectionString)
    #             $collection = $db.GetCollection('Location')
    #             $malformedEntries = $collection.Find($oidquery)
    #             $malformedEntries | Should -HaveCount 0
    #         }
    #     } finally {
    #         $db.Dispose()
    #     }
    # }
}
