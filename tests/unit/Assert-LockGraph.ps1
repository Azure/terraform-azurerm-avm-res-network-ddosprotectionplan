$ErrorActionPreference = 'Stop'
Push-Location (Join-Path $PSScriptRoot '..\..')
try {
    $graph = (& terraform graph) -join "`n"
    if ($LASTEXITCODE -ne 0) {
        throw 'terraform graph failed.'
    }
    if ($graph -notmatch '"azapi_resource\.lock" -> "azapi_resource\.role_assignments"') {
        throw 'The lock must depend on role assignments so full destroy removes the lock before deleting assignments.'
    }
    Write-Output 'Lock graph regression passed.'
}
finally {
    Pop-Location
}
