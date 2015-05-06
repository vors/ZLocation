Set-StrictMode -Version Latest

function Find-Matches([hashtable]$hash, [string[]]$query)
{
    $hash = $hash.Clone()
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
    function contains([string]$left, [string]$right) {
        return [bool]($left.IndexOf($right, [System.StringComparison]::OrdinalIgnoreCase) -ge 0)
    }

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
        if (-not (contains -left $path -right $query[$i]))
        {
            return $false
        }
    }   
    
    # after tab expansion, we get desired full path as a last query element.
    # tab expansion can come from our code, then it will represend the full path.
    # It also can come from the standart tab expension (when our doesn't return anything), which is file system based. 
    # It can produce relative paths.

    $rootQuery = $query[$n-1]

    if (-not [System.IO.Path]::IsPathRooted($rootQuery)) {
        # handle '..\foo' case
        $rootQueryCandidate = Join-Path $pwd $query[$n-1]
        if (Test-Path $rootQueryCandidate) {
            $rootQuery = (Resolve-Path $rootQueryCandidate).Path
        }
    }
    
    if ([System.IO.Path]::IsPathRooted($rootQuery)) 
    {
        # doing a tweak to handle 'C:' and 'C:\' cases correctly.
        if (($rootQuery.Length) -eq 2 -and ($rootQuery[-1] -eq ':'))
        {
            $rootQuery = $rootQuery + "\"
        }
        # doing a tweaks to handle 'C:\foo' and 'C:\foo\' cases correctly.
        elseif ($rootQuery[-1] -eq '\')
        {
            $rootQuery = $rootQuery.Substring(0, $rootQuery.Length-1)
        }
        return $path -eq $rootQuery
    }

    $leaf = Split-Path -Leaf $path
    return (contains -left $leaf -right $query[$n-1]) 
}

Export-ModuleMember -Function Find-Matches
