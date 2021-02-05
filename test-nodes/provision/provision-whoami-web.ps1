$name = 'whoami-web'
$installPath = "C:\$name"
$url = 'https://github.com/rgl/whoami-web/releases/download/v0.0.2/whoami-web.zip'
$hash = 'DE189EB6289083808D97C94C3155C8AD2668A821778C753DEA34A945FADD903E'

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
Install-Application $name $installPath $url $hash

Write-Host "Installing $name..."
cd $installPath
.\install.ps1

Write-Host "Creating the $name desktop shortcut..."
[IO.File]::WriteAllText("c:\Users\Public\Desktop\$name.url", @"
[InternetShortcut]
URL=http://localhost:9000
"@)
