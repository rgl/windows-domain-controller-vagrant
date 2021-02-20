# NB this script is executed in the client computer by gpscript.exe /Logoff.
# NB this file will be read by the client computer from the DC sysvol share, e.g.:
#       \\EXAMPLE.COM\sysvol\example.com\Policies\{2008196B-ADCE-4B60-BC80-F5EBAB0DFA1B}\User\Scripts\Logoff
# NB you can see logs about the execution of group policy scripts in the
#    client windows event viewer under the nodes:
#       Event Viewer (Local)
#           Applications and Services Logs
#               Microsoft
#                   Windows
#                       GroupPolicy
#                           Operational
#                       PowerShell
#                           Operational
#                       Winlogon
#                           Operational
#           Custom Views
#               Administrative Events

Set-StrictMode -Version Latest
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'

trap {
    Write-Output "ERROR: $_"
    Write-Output (($_.ScriptStackTrace -split '\r?\n') -replace '^(.*)$','ERROR: $1')
    Write-Output (($_.Exception.ToString() -split '\r?\n') -replace '^(.*)$','ERROR EXCEPTION: $1')
    Exit 1
}

Start-Transcript -IncludeInvocationHeader "C:\Windows\temp\$env:USERNAME-set-user-photo.log"

$searcher = New-Object System.DirectoryServices.DirectorySearcher
# NB We should not need to escape the $env:USERNAME value because it should
#    not contain any special characters, but YMMV.
$searcher.Filter = "(&(objectCategory=person)(objectClass=organizationalPerson)(sAMAccountName=$env:USERNAME))"
$searcher.PropertiesToLoad.AddRange(@(
    'photo'
))
$result = $searcher.FindOne()
if ($result) {
    $photos = $result.Properties['photo']
    if ($photos.Count) {
        Write-Output "Saving the $env:USERNAME user photo..."
        $photo = $photos[0]
        $accountSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        $accountPictureBasePath = "C:\Users\Public\AccountPictures\$accountSid"
        $accountRegistryKeyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AccountPicture\Users\$accountSid"
        # TODO only generate the images when the photo changes.
        mkdir -Force $accountPictureBasePath | Out-Null
        New-Item -Force $accountRegistryKeyPath | Out-Null
        Add-Type -AssemblyName System.Drawing
        $accountImage = [System.Drawing.Image]::FromStream((New-Object System.IO.MemoryStream(,$photo)))
        @(32,40,48,96,192,240,448) | ForEach-Object {
            $p = "$accountPictureBasePath\Image$($_).jpg"
            $i = New-Object System.Drawing.Bitmap($_, $_)
            $g = [System.Drawing.Graphics]::FromImage($i)
            $g.InterpolationMode = 'HighQualityBicubic'
            $g.DrawImage($accountImage, 0, 0, $_, $_)
            $i.Save($p)
            New-ItemProperty -Path $accountRegistryKeyPath -Name "Image$_" -Value $p -Force | Out-Null
        }
    } else {
        Write-Output "Could not find the $env:USERNAME user photo"
    }
} else {
    Write-Output "Could not find the $env:USERNAME user"
}
