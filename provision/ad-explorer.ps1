# install Active Directory Explorer from https://technet.microsoft.com/en-us/sysinternals/adexplorer.aspx
# NB even though you can use the Windows ADSI Edit application, I find ADExplorer nicer.
$adExplorerUrl = 'https://download.sysinternals.com/files/AdExplorer.zip'
$adExplorerHash = '97EF5001C225A869AE739C15AAB1E067B66CE85250FF4D3C265BBFAF09AC8308'
$adExplorer = 'c:/tmp/AdExplorer.zip' 
(New-Object System.Net.WebClient).DownloadFile($adExplorerUrl, $adExplorer)
$adExplorerActualHash = (Get-FileHash $adExplorer -Algorithm SHA256).Hash
if ($adExplorerHash -ne $adExplorerActualHash) {
    throw "AdExplorer.zip downloaded from $adExplorerUrl to $adExplorer has $adExplorerActualHash hash witch does not match the expected $adExplorerHash"
}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$Shell = New-Object -ComObject 'WScript.Shell'
$ShellSpecialFolders = $Shell.SpecialFolders
$adExplorerProgramFiles = Join-Path $env:ProgramFiles 'ADExplorer'
[IO.Compression.ZipFile]::ExtractToDirectory($adExplorer, $adExplorerProgramFiles)
$shortcut = $Shell.CreateShortcut((Join-Path $ShellSpecialFolders.Item('AllUsersStartMenu') 'Active Directory Explorer (ADExplorer).lnk'))
$shortcut.TargetPath = Join-Path $adExplorerProgramFiles 'ADExplorer.exe'
$shortcut.Save()
