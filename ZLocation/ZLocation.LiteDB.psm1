$mapper = [LiteDB.BSONMapper]::new()

Function Open([string]$connectionString) {
    [LiteDB.LiteDatabase]::new($connectionString)
}

Function Get-Collection($db, $name) {
    $db.GetCollection($name)
}

Function ToDocument($obj) {
    ,$mapper.ToDocument($obj)
}
Function ToObject($type, $obj) {
    ,$mapper.ToObject($type, $obj)
}

function Insert([LiteDB.LiteCollection[LiteDB.BSONDocument]]$collection, $item) {
    $collection.Insert((ToDocument $item)) | out-null
}

function Update([LiteDB.LiteCollection[LiteDB.BSONDocument]]$collection, $item) {
    $collection.Update((ToDocument $item))
}

function Delete([LiteDB.LiteCollection[LiteDB.BSONDocument]]$collection, $query) {
    $collection.Delete($query)
}

Function GetById([LiteDB.LiteCollection[LiteDB.BSONDocument]]$collection, $id, $type) {
    Find $collection ([LiteDB.Query]::EQ('_id', [LiteDB.BSONValue]::new($id))) $type
}

Function Find([LiteDB.LiteCollection[LiteDB.BSONDocument]]$collection, [LiteDB.Query]$query, $type) {
    ForEach($document in $collection.Find([LiteDB.Query]$query)) {
        ToObject $type $document
    }
}

Function CreateMatchQuery($matches) {
    $query = [LiteDB.Query]::All()
    ForEach($prop in (getEnum $matches)) {
        $query = [LiteDB.Query]::And([LiteDB.Query]::EQ($prop.Name, $prop.Value), $query)
    }
    ,$query
}
