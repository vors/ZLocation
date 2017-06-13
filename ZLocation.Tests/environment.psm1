# Set up the testing environment
if($IsLinux -eq $null -and $IsMac -eq $null) {
    $Global:IsWindows = $true
} else {
    $Global:IsUnix = $true
}
$Global:PathSep = [IO.Path]::DirectorySeparatorChar