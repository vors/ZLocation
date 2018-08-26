# Use a testing database; do not touch user's primary database
$testDb = Join-Path $PSScriptRoot '../ignored/z-location-tests.db'
if(-not (Test-Path (Split-Path -Parent $testdb))) { New-Item -Type Directory (Split-Path -Parent $testdb) }
if(Get-Module -all ZLocation.Service) {
    Mock -ModuleName ZLocation.Service Get-ZLocationDatabaseFilePath {
        $testDb
    }.getNewClosure() -ErrorAction SilentlyContinue
}
