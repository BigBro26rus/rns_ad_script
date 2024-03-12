function LoggingInfo {
    Param (
        [string]$Message,
        [string]$Path = $log_path
    )
    $logEntry = "$(Get-Date) - [INFO] $Message" 
    Add-Content -Path $Path -Value $logEntry -Encoding UTF8
}

function LoggingWarn {
    Param (
        [string]$Message,
        [string]$Path = $log_path
    )
    $logEntry = "$(Get-Date) - [WARNING] $Message"
    Add-Content -Path $Path -Value $logEntry -Encoding UTF8
}

function LoggingError {
    Param (
        [string]$Message,
        [string]$Path = $log_path
    )
    $logEntry = "$(Get-Date) - [ERROR] $Message" 
    Add-Content -Path $Path -Value $logEntry -Encoding UTF8
}

function getSamByDisplayName {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string[]]$DisplayNames
    )
    $result = @()
    foreach ($DisplayName in $DisplayNames) {
        $users = Get-ADUser -Filter "DisplayName -like '*$DisplayName*'" -Properties SAMAccountName -SearchBase $SearchBase
        if ($users) {
            foreach ($user in $users) {
                $result += $user.SAMAccountName
                Write-Host "$DisplayName found"
                LoggingInfo -Message "User found: DisplayName - $($DisplayName), SAMAccountName - $($user.SAMAccountName)"
            }
        } else {
            LoggingWarn -Message "User with DisplayName "$DisplayName" not found."
            Write-Host "$DisplayName not found"
        }
    }

    return $result
}

function addUsersToGroups {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$Usernames,

        [Parameter(Mandatory = $true)]
        [string[]]$Groups,

        [Parameter(Mandatory = $true)]
        [string]$ticket
    )
    
    if (-not (Test-Path -Path "$ticket_path\$ticket")) {
        New-Item -ItemType Directory -Path "$ticket_path\$ticket" | Out-Null
    }

    foreach ($User in $Usernames) {
        Write-Host "$User in progress"
        $addedGroups = @()
        $failedGroups = @()

        foreach ($Group in $Groups) {
            try {
                $ADUser = Get-ADUser -Identity $User -Properties MemberOf
                $ADGroup = Get-ADGroup $Group
                if ($ADUser.MemberOf -notcontains $ADGroup.DistinguishedName) {
                    Add-ADGroupMember -Identity $ADGroup -Members $ADUser -ErrorAction Stop
                    LoggingInfo "User- $User successfully added to the group- $Group."
                    $addedGroups += $Group
                } else {
                    LoggingWarn "User- $User already exists in group- $Group."
                }
            } catch {
                LoggingError -Message "$User could not be added to $Group. Error: $_"
                $failedGroups += $Group
            }
        }

        if ($addedGroups) {
            $addedGroupsString = $addedGroups -join ","
            $addedOutputString = "|$User|$addedGroupsString|"
            Add-Content -Path "$ticket_path\$ticket\successfully added.txt" -Value $addedOutputString -Encoding UTF8
        }

        if ($failedGroups) {
            $failedGroupsString = $failedGroups -join ","
            $failedOutputString = "|$User|$failedGroupsString|"
            Add-Content -Path "$ticket_path\$ticket\adding error.txt" -Value $failedOutputString -Encoding UTF8
        }
    }
}

function dropUsersFromGroups {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$Usernames,

        [Parameter(Mandatory = $true)]
        [string[]]$Groups,

        [Parameter(Mandatory = $true)]
        [string]$ticket
    )
     
    if (-not (Test-Path -Path "$ticket_path\$ticket")) {
        New-Item -ItemType Directory -Path "$ticket_path\$ticket" | Out-Null
    }

    foreach ($User in $Usernames) {
        Write-Host "$User in progress"
        $removedGroups = @()
        $failedGroups = @()

        foreach ($Group in $Groups) {
            try {
                $ADUser = Get-ADUser -Identity $User -Properties MemberOf
                $ADGroup = Get-ADGroup $Group
                if ($ADUser.MemberOf -contains $ADGroup.DistinguishedName) {
                    Remove-ADGroupMember -Identity $ADGroup -Members $ADUser -Confirm:$false -ErrorAction Stop
                    LoggingInfo -Message "User- $User successfully dropped from the group- $Group."
                    $removedGroups += $Group
                } else {
                    LoggingWarn -Message "User- $User is not a member of the group $Group, removal is not required."
                }
            } catch {
                LoggingError -Message "$User could not be dropped from $Group. Error: $_"
                $failedGroups += $Group
            }
        }
        if ($removedGroups) {
            $groupsString = $removedGroups -join ","
            $outputString = "|$User|$groupsString|"
            Add-Content -Path "$ticket_path\$ticket\successfully deleted.txt" -Value $outputString -Encoding UTF8
        }

        if ($failedGroups) {
            $failedGroupsString = $failedGroups -join ","
            $failedOutputString = "|$User|$failedGroupsString|"
            Add-Content -Path "$ticket_path\$ticket\deletion error.txt" -Value $failedOutputString -Encoding UTF8
        }
    }
}

function enableADUsers {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$Usernames,

        [Parameter(Mandatory = $true)]
        [string]$ticket
    )

    if (-not (Test-Path -Path "$ticket_path\$ticket")) {
        New-Item -ItemType Directory -Path "$ticket_path\$ticket" | Out-Null
    }

    foreach ($sam in $Usernames) {
        Write-Host "$sam in progress"
        try {
            $user = Get-ADUser -Identity $sam -ErrorAction Stop

            if ($user.Enabled -eq $true) {
                LoggingWarn "The user - $sam is already enabled."
                Add-Content -Path "$ticket_path\$ticket\active.txt" -Value "$sam" -Encoding UTF8
                Write-Host "$sam is already enabled"
                Add-Content -Path "$ticket_path\$ticket\enable.txt" -Value "$sam active" -Encoding UTF8
            } else {
                Enable-ADAccount -Identity $user -ErrorAction Stop
                LoggingInfo "The user - $sam has been enabled."
                Add-Content -Path "$ticket_path\$ticket\enabled.txt" -Value "$sam" -Encoding UTF8
                Write-Host "$sam has been enabled"
                Add-Content -Path "$ticket_path\$ticket\enable.txt" -Value "$sam enabled" -Encoding UTF8
            }
        } catch {
            LoggingError "Error attempting to enable user $sam : $_"
        }
    }
}

function checkEnableADUsers {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$Usernames,

        [Parameter(Mandatory = $true)]
        [string]$ticket
    )
 
    if (-not (Test-Path -Path "$ticket_path\$ticket")) {
        New-Item -ItemType Directory -Path "$ticket_path\$ticket" | Out-Null
    }
    
    foreach ($sam in $Usernames) {
        try {
            $user = Get-ADUser -Identity $sam -ErrorAction Stop

            if ($user.Enabled -eq $true) {
                LoggingWarn "The user - $sam enable."
                Write-Host "$sam enable"
                Add-Content -Path "$ticket_path\$ticket\status.txt" -Value "$sam active" -Encoding UTF8
            } else {
                LoggingInfo "The user - $sam disable."
                Add-Content -Path "$ticket_path\$ticket\status.txt" -Value "$sam disabled" -Encoding UTF8
                Write-Host "$sam disabled"

            }
        } catch {
            LoggingError "Error attempting to enable user $sam : $_"
        }
    }
}

function backupGroups {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$users_sam,

        [Parameter(Mandatory = $true)]
        [string[]]$ticket
    )

    foreach ($user in $users_sam) {
        Write-Host "Backup for $user"
        $groups = Get-ADPrincipalGroupMembership $user |
                  Select-Object -ExpandProperty SamAccountName
        $groupsString = $groups -join ","
        $outputString = "$ticket;$user;$groupsString"
        Add-Content -Path $backup_path -Value $outputString -Encoding UTF8
        LoggingInfo "Backup for $user complete."
    }
}

function removeUsersFromAllGroups {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$Usernames,

        [Parameter(Mandatory = $true)]
        [string]$ExcludePattern,

        [Parameter(Mandatory = $true)]
        [string]$ticket
    )
 
    if (-not (Test-Path -Path "$ticket_path\$ticket")) {
        New-Item -ItemType Directory -Path "$ticket_path\$ticket" | Out-Null
    }

    foreach ($Username in $Usernames) {
        $User = Get-ADUser -Identity $Username -Properties MemberOf -ErrorAction SilentlyContinue
        $removedGroupsList = @()
        $failedGroupsList = @()

        if ($User -and $User.MemberOf) {
            foreach ($GroupDN in $User.MemberOf) {
                $GroupName = (Get-ADGroup -Identity $GroupDN).Name
                if ($GroupName -notmatch $ExcludePattern) {
                    try {
                        Remove-ADGroupMember -Identity $GroupName -Members $Username -Confirm:$false -ErrorAction SilentlyContinue
                        LoggingInfo -Message "User $Username has been removed from the group $GroupName."
                        $removedGroupsList += $GroupName
                    } catch {
                        LoggingError -Message "Error removing user $Username from the group $GroupName. Error: $_"
                        $failedGroupsList += $GroupName
                    }
                }
            }
        } else {
            LoggingInfo -Message "User $Username does not have any groups to be removed from or does not exist."
        }
        if ($removedGroupsList) {
            $removedGroupsString = $removedGroupsList -join ","
            $removedOutputString = "|$Username|$removedGroupsString|"
            Add-Content -Path "$ticket_path\$ticket\drop-all-group.txt" -Value $removedOutputString -Encoding UTF8
        }
        if ($failedGroupsList) {
            $failedGroupsString = $failedGroupsList -join ","
            $failedOutputString = "|$Username|$failedGroupsString|"
            Add-Content -Path "$ticket_path\$ticket\deletion error.txt" -Value $failedOutputString -Encoding UTF8
        }

        Write-Host "$Username complete"
    }
}
