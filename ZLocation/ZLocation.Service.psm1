Set-StrictMode -Version Latest

Import-Module -Prefix DB (Join-Path $PSScriptRoot 'ZLocation.LiteDB.psd1')

class Service {
    [LiteDB.LiteCollection[LiteDB.BSONDocument]] $collection;
    # TODO create a LiteDB database and collection instance
    [Collections.Generic.IEnumerable[Location]] Get() {
        # Return an enumerator of all location entries
        [Location[]]$arr = DBFind $this.collection ([LiteDB.Query]::All()) ([Location])
        return $arr
    }
    [void] Add([string]$path, [double]$weight) {
        $l = DBGetById $this.collection $path ([Location])
        if($l) {
            $l.weight += $weight
            DBUpdate $this.collection $l
        } else {
            $l = [Location]::new()
            $l.path = $path
            $l.weight = $weight
            DBInsert $this.collection $l
        }
    }
    [void] Remove([string]$path) {
        # Use DB's internal column name, not mapped name
        DBDelete $this.collection ([LiteDB.Query]::EQ('_id', [LiteDB.BSONValue]::new($path)))
    }
}

class Location {
    [LiteDB.BsonId()]
    [string] $path;

    [double] $weight;
}

function Get-ZLocationDatabaseFilePath
{
    return (Join-Path $env:USERPROFILE 'z-location.db')
}

$service = [Service]::new()
$db = DBOpen (Get-ZLocationDatabaseFilePath)
$collection = Get-DBCollection $db 'location'
$collection.EnsureIndex('path')
$service.collection = $collection

Function Get-ZService {
    ,$service
}
