Function Get-SiteMailboxes {
    [cmdletbinding(positionalbinding=$false)]
    Param (
        [parameter(Mandatory=$True,Position=0)][string[]]$inputfile,
        [parameter(Mandatory=$True,Position=1)][string[]]$site,
        [parameter(Mandatory=$True,Position=2)]
        [ValidateSet("Employee","Contractor","All")][String[]]$accounttype
        )

    Process {
        Clear-Host
        If ((Test-Path $inputfile) -eq $false) {
            Write-Host "STOP! Inputfile does not exist. Please revalidate syntax and run again." -ForegroundColor Red
            BREAK
            }

        Write-Host "Retrieving File: $($inputfile)"  -ForegroundColor Cyan -backgroundcolor Blue
        $UserListCSV = Get-Content $inputfile
        $Header = "EmailAddress,UserPrincipalName,Site,MailboxSizeGB,AccountType"

        If ($UserListCSV[0] -ne $Header) {
            Write-Host "STOP! Inputfile Header Format. Please revalidate data file and run again." -ForegroundColor Red
            Write-Host "> Expected Header: $($Header)" -ForegroundColor Red
            BREAK
            }

        If ($accounttype -eq "All") {$accounttype2 = "*"} ELSE {$accounttype2 = $accounttype}
        Write-Host "> Parsing $($accounttype) Account Types in Site $($site)" -ForegroundColor Cyan
        
        $UserList = $UserListCSV | ConvertFrom-CSV
        
        Write-host "> Total Number of Users in $($inputfile): $($UserList | measure-object | select -ExpandProperty Count)" -ForegroundColor Cyan
        Write-host "> Total Size (GB) of all Mailboxes in $($inputfile): $($UserList | measure-object MailboxSizeGB -Sum | select -ExpandProperty Sum)" -ForegroundColor Cyan
        Write-host "> Number of Users in $($inputfile) with non-identical EmailAddress & UserPrincipalName: $($UserList.where({$_.emailaddress -cne $_.userprincipalname}) | Measure-Object | select -ExpandProperty count)" -ForegroundColor Cyan
        Write-host "> Top 10 $($accounttype) AccountType in Site: $($site)" -ForegroundColor Cyan
        $UsersTop10 = $UserList | where {$_.site -like $Site -and $_.AccountType -like $AccountType2} | sort @{E={$_.MailboxSizeGB -as [int]}} -Descending | select -First 10
        $UsersTop10 | ft -Autosize

        Write-Host "> Top 10 Usernames in Site: $($Site)" -ForegroundColor Cyan
        If ($UsersTop10 -ne $Null) {($UsersTop10.EmailAddress | foreach {($_).split("@")[0]}) -join " "}
        
        $SiteNames = $UserList.Site | sort -Unique
        $SiteMBXMetrics = $MetricsObj = @()

        Write-Host "> Generating User Mailbox Metrics by Site..." -ForegroundColor Cyan
        Foreach ($SiteA in $SiteNames) {
            $SiteUsers = $UserList.where({$_.Site -eq $SiteA})
            $MetricsObj = $SiteA | select @{N="Site";E={$SiteA}}, `
                                          @{N="TotalUserCount";E={$SiteUsers | Measure-Object | select -Expandproperty Count}}, `
                                          @{N="EmployeeCount";E={$SiteUsers.where({$_.AccountType -eq "Employee"}) | Measure-Object | select -Expandproperty Count}}, `
                                          @{N="ContractorCount";E={$SiteUsers.where({$_.AccountType -eq "Contractor"}) | Measure-Object | select -Expandproperty Count}}, `
                                          @{N="TotalMailboxSize";E={[Math]::Round(($SiteUsers | Measure-Object -Property MailboxSizeGB -Sum | Select -ExpandProperty Sum),1).tostring("#.0")}}, `
                                          @{N="AverageMailboxSizeGB";E={[Math]::Round(($SiteUsers | Measure-Object -Property MailboxSizeGB -Average | Select -ExpandProperty Average),1).tostring("#.0")}}
            $SiteMBXMetrics += $MetricsObj
            }

        $SiteMBXMetrics | Export-Csv "UserMailboxMetricsBySite.csv" -Confirm:$false -Force
        
        Write-Host "> User Mailbox Metrics by Site:" -ForegroundColor Cyan
        $SiteMBXMetrics | ft -autosize
        
        Write-Host "> Output User Mailbox Metrics by Site: UserMailboxMetricsBySite.csv" -ForegroundColor Cyan
        }
    }