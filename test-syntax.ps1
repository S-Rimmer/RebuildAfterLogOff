# Test PowerShell syntax validation
param(
    [string]$FilePath
)

try {
    $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $FilePath -Raw), [ref]$null)
    Write-Host "Syntax is valid"
}
catch {
    Write-Host "Syntax error: $($_.Exception.Message)"
    Write-Host "Line: $($_.Exception.ErrorRecord.InvocationInfo.ScriptLineNumber)"
}
