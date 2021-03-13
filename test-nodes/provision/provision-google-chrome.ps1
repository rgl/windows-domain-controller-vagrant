# install Google Chrome.
# see https://www.chromium.org/administrators/configuring-other-preferences
choco install -y --ignore-checksums googlechrome
$chromeLocation = 'C:\Program Files\Google\Chrome\Application'
cp -Force GoogleChrome-external_extensions.json (Resolve-Path "$chromeLocation\*\default_apps\external_extensions.json")
cp -Force GoogleChrome-master_preferences.json "$chromeLocation\master_preferences"

# set default applications.
choco install -y SetDefaultBrowser
SetDefaultBrowser HKLM "Google Chrome"
