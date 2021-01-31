$name = 'whoami-web'
$url = 'https://github.com/rgl/whoami-web/releases/download/v0.0.1/whoami-web.zip'
$hash = '577A99B7CAD8CD7F06DE1AAD2B21E43F33B330456BCB778D3A96051807954BD2'

# define the Install-Application function that downloads and unzips an application.
Add-Type -AssemblyName System.IO.Compression.FileSystem
function Install-Application($name, $destinationPath, $url, $expectedHash, $expectedHashAlgorithm = 'SHA256') {
    $localZipPath = "$env:TEMP\$name.zip"
    (New-Object Net.WebClient).DownloadFile($url, $localZipPath)
    $actualHash = (Get-FileHash $localZipPath -Algorithm $expectedHashAlgorithm).Hash
    if ($actualHash -ne $expectedHash) {
        throw "$name downloaded from $url to $localZipPath has $actualHash hash that does not match the expected $expectedHash"
    }
    [IO.Compression.ZipFile]::ExtractToDirectory($localZipPath, $destinationPath)
}

Write-Host "Downloading $name from $url..."
Install-Application $name "C:\$name" $url $hash

Write-Host "Creating the $name windows service..."
$result = sc.exe create $name `
    DisplayName= 'Who Am I?' `
    binPath= "C:\$name\whoami.exe" `
    obj= 'EXAMPLE\whoami$' `
    start= auto
if ($result -ne '[SC] CreateService SUCCESS') {
    throw "sc.exe create failed with $result"
}
$result = sc.exe description $name `
    'The introspective service'
if ($result -ne '[SC] ChangeServiceConfig2 SUCCESS') {
    throw "sc.exe description failed with $result"
}
$result = sc.exe failure $name `
    reset= '0' `
    actions= 'restart/60000'
if ($result -ne '[SC] ChangeServiceConfig2 SUCCESS') {
    throw "sc.exe failure failed with $result"
}

Write-Host "Starting the $name windows service..."
Start-Service $name

Write-Host "Creating the $name desktop shortcut..."
[IO.File]::WriteAllText("c:\Users\Public\Desktop\$name.url", @"
[InternetShortcut]
URL=http://localhost:9000
"@)
