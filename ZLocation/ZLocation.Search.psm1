Set-StrictMode -Version Latest

if ((Get-Variable IsWindows -ErrorAction Ignore) -eq $null) { $IsWindows = $true }

function Find-Matches {
    param (
        [Parameter(Mandatory=$true)] [hashtable]$hash, 
        [string[]]$query
    )
    $hash = $hash.Clone()
    foreach ($key in ($hash.GetEnumerator() | %{$_.Name}))
    {
        if (-not (Test-FuzzyMatch $key $query))
        {
            $hash.Remove($key)
        }
    }

    if ($query -ne $null -and $query.Length -gt 0) {
        $lowerPrefix = $query[-1].ToLower()
        # we should prefer paths that start with the query over paths with bigger weight
        # that don't.
        # i.e. if we have
        # /foo = 1.0
        # /afoo = 2.0
        # and query is "fo", we should prefer /foo
        # Similarly, with the same query `fo`, the full match `/fo` should win over `/fo2`
        $res = $hash.GetEnumerator() | % {
            New-Object -TypeName PSCustomObject -Property @{
                Name=$_.Name
                Value=$_.Value
                Starts=[int](Start-WithPrefix -Path $_.Name -lowerPrefix $lowerPrefix)
                IsExactMatch=[int](IsExactMatch -Path $_.Name -lowerPrefix $lowerPrefix)
            }
        } | Sort-Object -Property IsExactMatch, Starts, Value -Descending
    } else {
        $res = $hash.GetEnumerator() | Sort-Object -Property Value -Descending
    }

    if ($res) {
        $res | %{$_.Name}
    }
}

function Start-WithPrefix {
    param (
        [Parameter(Mandatory=$true)] [string]$Path, 
        [Parameter(Mandatory=$true)] [string]$lowerPrefix
    )
    $lowerLeaf = (Split-Path -Leaf $Path).ToLower()
    return $lowerLeaf.StartsWith($lowerPrefix)
}

function IsExactMatch {
    param (
        [Parameter(Mandatory=$true)] [string]$Path, 
        [Parameter(Mandatory=$true)] [string]$lowerPrefix
    )
    $lowerLeaf = (Split-Path -Leaf $Path).ToLower()
    return $lowerLeaf -eq $lowerPrefix
}

function Test-FuzzyMatch {
    param (
        [Parameter(Mandatory=$true)] [string]$path,
        [string[]]$query
    )
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
    # tab expansion can come from our code, then it will represent the full path.
    # It also can come from the standard tab expansion (when our doesn't return anything), which is file system based.
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
        if ($IsWindows -and ($rootQuery.Length) -eq 2 -and ($rootQuery[-1] -eq ':'))
        {
            $rootQuery = $rootQuery + "\"
        }
        # doing a tweaks to handle 'C:\foo' and 'C:\foo\' cases correctly.
        elseif ($rootQuery -ne '/' -and $rootQuery[-1] -eq [IO.Path]::DirectorySeparatorChar)
        {
            $rootQuery = $rootQuery.Substring(0, $rootQuery.Length-1)
        }
        return $path -eq $rootQuery
    }

    $leaf = Split-Path -Leaf $path
    return (contains -left $leaf -right $query[$n-1])
}

Export-ModuleMember -Function Find-Matches
