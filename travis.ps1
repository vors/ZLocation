$res = Invoke-Pester $PSScriptRoot\ZLocation.Tests -PassThru
if ($res.FailedCount -gt 0) {
    throw "$($res.FailedCount) tests failed."
}