$response = (Invoke-WebRequest 'https://www.sumatrapdfreader.org/free-pdf-reader.html')
$matches = [regex]::Match($response.Content,'/prerelease">([\d.]+)<span')

if ($matches.Success) {

  $verHead = $matches.groups[1].Value
  $js = (wget 'https://files2.sumatrapdfreader.org/software/sumatrapdf/sumatralatest.js')
  $jsContent = $js.Content
  $verMatch = [regex]::Match($jsContent,'sumLatestVer=(\d+);')
  if ($vermatch.Success) {
    $verTail = $verMatch.groups[1].Value
    $verHead
  }
}

#Start-Process -Wait  "D:\Backup\Downloads\SumatraPDF-prerel-64-install.exe" -ArgumentList '-d', "D:\Backup\Downloads\sumatralatest", '-with-preview' -ErrorAction SilentlyContinue
$vinfo='v'
$jsonObj = (Invoke-WebRequest https://ci.appveyor.com/api/projects/rizonesoft/notepad3).Content | ConvertFrom-Json
$jsonObj.build.jobs | ForEach-Object {
  if ($_.Name -eq 'Platform: x64') {

    if ($_.status -eq "success") {
      $jobId = $_.jobId

      $consoleLog = " https://ci.appveyor.com/api/buildjobs/$jobId/console"
      $versionObj = (Invoke-WebRequest $consoleLog).Content
      $versionInfo = [regex]::Match($versionObj,"64-bit exe Version = ([\d.]+)")
      if ($versionInfo.Success) {
        $vinfo += $versionInfo.groups[1].Value
      }
      $baseUrl = "https://ci.appveyor.com/api/buildjobs/$jobId/artifacts"
      $artifsObj = (Invoke-WebRequest $baseUrl).Content | ConvertFrom-Json
      $artifsObj | ForEach-Object {
        $filePath = $_.fileName
        Write-Host "$baseUrl/$filePath"
        #Invoke-WebRequest "$baseUrl/$filePath" -OutFile ([System.IO.FileInfo]$filePath).Name
        if (([System.IO.FileInfo]$filePath).Name -eq "Notepad3.exe") {
          (Get-Item "Notepad3.exe").VersionInfo.FileVersion
          $vinfo += "-$baseUrl/$filePath"
        }
      }
    }
  }
}
$vinfo

#https://www.appveyor.com/docs/api/samples/download-artifacts-ps/
$apiUrl = 'https://ci.appveyor.com/api'
$token = '<your-api-token>'
$headers = @{
  "Authorization" = "Bearer $token"
  "Content-type" = "application/json"
}
$accountName = '<your-account-name>'
$projectSlug = '<your-project-slug>'

$downloadLocation = 'C:\projects'

# get project with last build details
$project = Invoke-RestMethod -Method Get -Uri "$apiUrl/projects/$accountName/$projectSlug" -Headers $headers

# we assume here that build has a single job
# get this job id
$jobId = $project.build.jobs[0].jobId

# get job artifacts (just to see what we've got)
$artifacts = Invoke-RestMethod -Method Get -Uri "$apiUrl/buildjobs/$jobId/artifacts" -Headers $headers

# here we just take the first artifact, but you could specify its file name
# $artifactFileName = 'MyWebApp.zip'
$artifactFileName = $artifacts[0].fileName

# artifact will be downloaded as
$localArtifactPath = "$downloadLocation\$artifactFileName"

# download artifact
# -OutFile - is local file name where artifact will be downloaded into
# the Headers in this call should only contain the bearer token, and no Content-type, otherwise it will fail!
Invoke-RestMethod -Method Get -Uri "$apiUrl/buildjobs/$jobId/artifacts/$artifactFileName" `
-OutFile $localArtifactPath -Headers @{ "Authorization" = "Bearer $token" }
