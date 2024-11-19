Param(
        [string]$hDir,
        [string]$sf
     )

Get-ChildItem $hDir -Recurse -File| ForEach-Object {
    $hInfo = Get-FileHash -Path $_.fullname -Algorithm SHA256 
    Add-Content -Path $sf -Value "$($hInfo.path)    $($hInfo.hash)"
}
