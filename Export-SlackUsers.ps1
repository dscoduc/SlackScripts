<#
.Synopsis
    Retrieves and returns a list of users from Slack

.Description
    Retrieves and returns a list of users from Slack

.Parameter AuthorizationToken
    Slack authorization token with permissions to perform the request (e.g. xoxp-123...")

.Parameter Id
    Single user Id to request (Optional)

.Example
    Export-SlackUsers.ps1 -AuthorizationToken $AUTHTOKEN

.Example
    Export-SlackUsers.ps1 -AuthorizationToken $AUTHTOKEN -Id U123456789

.Example
    Export-SlackUsers.ps1 -AuthorizationToken $AUTHTOKEN | Select Id

.Example
    Export-SlackUsers.ps1 -AuthorizationToken $AUTHTOKEN | ? { $_.Active -eq $False }

.Example
    "U123456789","U987654321" | .\Export-SlackUsers.ps1 -AuthorizationToken $AUTHTOKEN

.Notes
    Author  : chris@dscoduc.com
    Date    : 11/17/2020
    Version : v1.0
.Link 
    https://api.slack.com/scim
#>
[CmdletBinding(DefaultParameterSetName="Default", SupportsShouldProcess)]
param(
    [Parameter(Mandatory, ParameterSetName="Default", HelpMessage="Slack Oauth Authorization Token (e.g. xoxp-123...")]
    [string]$AuthorizationToken,

    [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [string]$Id
)
Begin {
    $Error.Clear()
    Set-StrictMode -Version Latest
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    function newUserObject {
        Param (
            [Parameter(Mandatory)]
            [object]$entry
        )

        Write-Verbose "Creating new user object for $($entry.id)"

        [PSCustomObject]$userObject = [PSCustomObject]@{
                Id          = $entry.id
                UserName    = $entry.userName
                GivenName   = $entry.name.givenName
                FamilyName  = $entry.name.familyName
                NickName    = $entry.nickName
                DisplayName = $entry.displayName
                Title       = $entry.title
                Active      = $entry.active
                Email       = $entry.emails.Item(0).value
                ProfileUrl  = $entry.profileUrl
                Timezone    = $entry.timezone
                Created     = $entry.meta.created
                location    = $entry.meta.location
            }
        
            return $userObject
    }

    function Export-SlackUser() {
        [cmdletbinding()]
        Param (
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$token,

            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$userId
        )

        try {
            Write-Verbose "Sending request to Slack..."
            $result = Invoke-RestMethod -Method Get -Headers @{'Authorization' = 'Bearer ' + $token} -Uri "https://api.slack.com/scim/v1/Users/$userId"
            if($result -eq $null) { throw "A null response was returned from Slack Api." }

            [PSCustomObject]$slackUser = newUserObject -entry $result
            return $slackUser
        }
        catch {
            $statusCode = $_.Exception.Response.StatusCode

            if($statusCode -eq "NotFound") {
                Write-Warning "$userId [$($statusCode)]"
            }
            else {
                Write-Warning $_.Exception.Message
            }
                
            $Error.Clear()
        }
    }

    function Export-SlackUsers() {
        Param (
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$token
        )

        [System.Collections.ArrayList]$users = @()
        [int]$maxPagesToRequest = 25
        [int]$recordsPerPage = 1000
        [int]$startIndex = 1
        
        Write-Verbose "Sending paged requests to Slack"
        For ($currentPage=0; $currentPage -le $maxPagesToRequest; $currentPage++) {

                try {
                    Write-Verbose "Sending request to Slack..."

                    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                    $result = Invoke-RestMethod -Method Get -Headers @{'Authorization' = 'Bearer ' + $token} -Uri "https://api.slack.com/scim/v1/Users?count=$recordsPerPage&startIndex=$startIndex"  
                    if($result -eq $null) { throw "A null response was returned from Slack Api." }

                    Write-Verbose "Total Results: $($result.totalResults)"
                    Write-Verbose "Start Index: $($result.startIndex)"
                    Write-Verbose "Entries returned: $($result.Resources.Count)"

                    if($result.Resources.Count -eq 0) {
                        Write-Verbose "No more records to retrieve, exiting..."
                        break
                    }

                    foreach($resource in $result.Resources) {                    
                        [PSCustomObject]$slackUser = newUserObject -entry $resource
                        $users.Add($slackUser) | Out-Null
                    }
                }
                catch {
                    Write-Warning $_.Exception.Message
                    $Error.Clear()
                    break
                }

                $startIndex = $startIndex + $recordsPerPage
            }

        Write-Verbose "Returning $($users.Count) entries"
        return $users
    }
}
Process {
    if($Id) {
        Export-SlackUser -token $authToken -userId $Id
    }
    else {
        Export-SlackUsers -token $authToken
    }
}
End {
    $authToken = $null
    Write-Verbose "Script completed"
    Exit(0)
}
