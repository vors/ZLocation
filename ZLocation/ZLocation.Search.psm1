Set-StrictMode -Version Latest

function Find-Matches([hashtable]$hash, [string[]]$query)
{
    foreach ($key in ($hash.GetEnumerator() | %{$_.Name})) 
    {
        if (-not (Test-FuzzyMatch $key $query)) 
        {
            $hash.Remove($key)
        }
    }
    $res = $hash.GetEnumerator() | sort -Property Value -Descending
    if ($res) {
        $res | %{$_.Name}
    }
}

function Test-FuzzyMatch([string]$path, [string[]]$query)
{
    if ($query -eq $null) {
        return $true
    }
    $n = $query.Length
    if ($n -eq 0)
    {
        # empty query match to everything
        return $true
    }

    for ($i=0; $i -lt $n-1; $i++)
    {
        if (-not ($path -match $query[$i]))
        {
            return $false
        }
    }   
    
    # after tab expansion, we get desired full path as a last query element.
    if ([System.IO.Path]::IsPathRooted($query[$n-1])) 
    {
        return $path -eq $query[$n-1]
    }

    $leaf = Split-Path -Leaf $path
    return ($leaf -match $query[$n-1]) 
}
