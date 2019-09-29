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
        }
    }

    Context 'Testing database functionality' {
        InModuleScope ZLocation.Service {
            $dbpath = Get-ZLocationDatabaseFilePath
            $testdbpattern = '*z-location-tests.db'
            if ($dbpath -notlike $testdbpattern) {throw 'Not using test database, aborting tests'}
            if (-not (Test-ZLocationDBUnlocked)) {throw 'Database is locked, aborting tests'}

            $path = [guid]::NewGuid().Guid 
            $service = Get-ZService
            $count = $service.get() | Measure-Object | Select-Object -ExpandProperty Count

            It 'Adds and retrieves a location' {
                $service.add($path, 1)
                $service.get() | Should -HaveCount ($count + 1)
                $l = [Location]::new()
                $l.path = $path
                $l.weight = 1
                $service.get() | Where-Object { $_.Path -eq $path } | Should -HaveCount 1
            }

            It 'Adds and removes a location' {
                $service.add($path, 1)
                $service.Remove($path)
                $service.get() | Measure-Object | Select-Object -ExpandProperty Count | Should -Be $count
            }
        }
    }

    Context "Malformed DB entries" {
        try {
            # Connect to the database and add some malformed entries
            Add-Type -Path $PSScriptRoot\..\ZLocation\LiteDB\LiteDB.dll
            $connectionString = "Filename=$($testDb); Mode=Shared"
            $db = [LiteDB.LiteDatabase]::new($connectionString)
            $collection = $db.GetCollection('Location')
            $oidquery = [LiteDB.Query]::Where('_id',{$args -like '{"$oid":"*"}'})
            
            # Create and insert a malformed location
            $bsondocument = [LiteDB.BsonDocument]::new()
            $bsondocument['weight'] = 1234
            $collection.Insert($bsondocument)

            It "confirms malformed entries inserted" {
                # This actually tests the query more than anything.
                $malformedEntries = (,$collection.Find($oidquery))
                $malformedEntries | Should -HaveCount 1
            }

            It "can remove malformed location entries" {
                # Ensure nothing else can be connecting to $db to placate AppVeyor.
                $db.Dispose()
                $service = Get-ZService
                $service.get()
                $db = [LiteDB.LiteDatabase]::new($connectionString)
                $collection = $db.GetCollection('Location')
                $malformedEntries = $collection.Find($oidquery)
                $malformedEntries | Should -HaveCount 0
            }
        } finally {
            $db.Dispose()
        }
    }
}
