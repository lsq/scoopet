$dirPath = "C:\Users\Administrator\scoop\cache"
Get-ChildItem -Path $dirPath -file | ForEach-Object { 
  $fname = $_.Name
  $fmatch = [regex]::Matches($fname, "notepad3-pre")
  if ($fmatch.Success) {
    #$manifest_hash = hash_for_url $manifest $url $architecture
    #$ok, $err = check_hash $_ $manifest_hash $(show_app $app $bucket) 
    #if ($ok) {    
    #Rename-Item -Force $_ $data.$url.source
    Write-Host $_.FullName
  }
}