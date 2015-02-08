task default -depends Test

task Test {
    Invoke-Pester $PSScriptRoot\ZLocation.Tests
}

task AppveyorTest {
    $testResultsFile = ".\TestsResults.xml"
    $res = Invoke-Pester -OutputFormat NUnitXml -OutputFile $testResultsFile -PassThru
    (New-Object 'System.Net.WebClient').UploadFile("https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)", (Resolve-Path $testResultsFile))
    if ($res.FailedCount -gt 0) { 
        throw "$($res.FailedCount) tests failed."
    }
}
