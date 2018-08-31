Set-StrictMode -Version Latest

Import-Module -Prefix DB (Join-Path $PSScriptRoot 'ZLocation.LiteDB.psd1')

class Service {
    [Collections.Generic.IEnumerable[Location]] Get() {
        return (dboperation {
            # Return an enumerator of all location entries
            [Location[]]$arr = DBFind $collection ([LiteDB.Query]::All()) ([Location])
            ,$arr
        })
    }
    [void] Add([string]$path, [double]$weight) {
        dboperation {
            $l = DBGetById $collection $path ([Location])
            if($l) {
                $l.weight += $weight
                DBUpdate $collection $l
            } else {
                $l = [Location]::new()
                $l.path = $path
                $l.weight = $weight
                DBInsert $collection $l
            }
        }
    }
    [void] Remove([string]$path) {
        dboperation {
            # Use DB's internal column name, not mapped name
            DBDelete $collection ([LiteDB.Query]::EQ('_id', [LiteDB.BSONValue]::new($path)))
        }
    }
}

class Location {
    [LiteDB.BsonId()]
    [string] $path;

    [double] $weight;
}

function Get-ZLocationDatabaseFilePath
{
    return (Join-Path $HOME 'z-location.db')
}
# Returns path to legacy ZLocation backup file.
function Get-ZLocationLegacyBackupFilePath
{
    if($env:USERPROFILE -ne $null) {
        Join-Path $env:USERPROFILE 'z-location.txt'
    }
}

<#
 Open database, invoke a database operation, and close the database afterwards.
 This is necessary for safe multi-process concurrency.
 See: https://github.com/mbdavid/LiteDB/wiki/Concurrency
 Exposes $db and $collection variables for use by the $scriptblock
#>
function dboperation($private:scriptblock) {
    $Private:Mode = if( $IsMacOS ) { 'Exclusive' } else { 'Shared' }
    # $db and $collection will be in-scope within $scriptblock
    $db = DBOpen "Filename=$( Get-ZLocationDatabaseFilePath ); Mode=$Mode"
    $collection = Get-DBCollection $db 'location'
    try {
        & $private:scriptblock
    } finally {
        $db.dispose()
    }
}

$dbExists = Test-Path (Get-ZLocationDatabaseFilePath)
$legacyBackupPath = Get-ZLocationLegacyBackupFilePath
$legacyBackupExists = ($legacyBackupPath -ne $null) -and (Test-Path $legacyBackupPath)

# Create empty db, collection, and index if it doesn't exist
dboperation {
    $collection.EnsureIndex('path')
}

$service = [Service]::new()

# Migrate legacy backup into database if appropriate
if((-not $dbExists) -and $legacyBackupExists) {
    Get-Content $legacyBackupPath | Filter-Object { $_ -ne $null } | ForEach-Object {
        $split = $_ -split '`t'
        $service.add($split[0], $split[1])
    }
}

Function Get-ZService {
    ,$service
}
