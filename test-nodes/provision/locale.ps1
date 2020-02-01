$ErrorActionPreference = 'Stop'

#
# current user.

# set keyboard layout.
# NB you can get the name from the list:
#      [System.Globalization.CultureInfo]::GetCultures('InstalledWin32Cultures') | out-gridview
Set-WinUserLanguageList pt-PT -Force

# set the date format, number format, etc.
Set-Culture pt-PT

# set the timezone.
# tzutil /l lists all available timezone ids
& $env:windir\system32\tzutil /s "GMT Standard Time"


#
# lock screen settings (this incidentally(?) also changes its locale).

# NB this is a modified (no prompting or restarting) of the function available at:
#       http://www.powershellmagazine.com/2014/03/24/set-keyboard-layouts-available-on-logon-screen-in-windows-8-1/ 
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.InternationalSettings.Commands') | Out-Null
function Set-WinLogonLanguageList {
    <#
    .SYNOPSIS
    Sets the keyboards visible on the logon screen

    .DESCRIPTION
    This function provides automated way to copy the keyboard settings of the current user to the Windows logon screen.
    It provides part of the functionality available in Region and Language Settings control panel.
    Region and Language Settings > Administrative > Copy settings... ->
    Copy to New Users and Welcome Screen > Welcome screen and system accounts

    Computer restart is needed after the change.

    .PARAMETER LanguageList
    Accepts list of user language objects.

    .EXAMPLE
    Get-WinUserLanguageList | Set-WinLogonKeyboardList -Force

    Sets the keyboard layouts of the current user to be available on the logon screen without asking for confirmation.
    #>
    
    param(
        [Parameter(
            Mandatory=$true,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName = $true
        )]
        [Microsoft.InternationalSettings.Commands.WinUserLanguage[]]
        $LanguageList
    )

    begin {
        $list = @()
    }

    process {
        foreach ($language in $LanguageList) {
            $list += $language
        }
    }

    end {
        $path = "Microsoft.PowerShell.Core\Registry::HKEY_USERS\.Default\Keyboard Layout\preload"

        # remove the current registry settings
        $current = (Get-Item $path).Property
        Remove-ItemProperty -Path $path -Name $current -Force

        # remove languages that are not installed on the system
        if ($list | where { -not $_.Autonym }) {
            Write-Warning "The list you attempted to set contained invalid langauges which were ignored"
            $finalList = $list | where Autonym
        } else {
            $finalList = $list
        }

        $languageCode = $finalList.InputMethodTips -replace  ".*:"

        for ($i = 0; $i -lt $languageCode.count; ++$i) {
            New-ItemProperty -Path $path -Name ($i+1) -Value $languageCode[$i] -PropertyType String -Force | Out-Null
        }
    }
}

Set-WinLogonLanguageList -LanguageList pt-PT,en-US
