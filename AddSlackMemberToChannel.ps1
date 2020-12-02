<# #########################################################
 Description : Add member to Slack channel
 
 Usage       : .\AddMemberToChannel.ps1 -UserEmail {email} -ChannelId {channel} -AuthorizationToken {token}
             : .\AddMemberToChannel.ps1 -UserId {Slack_User_ID} -ChannelId {channel} -AuthorizationToken {token}
             : .\AddMemberToChannel.ps1 -ImportFile {Import_File} -ChannelId {channel} -AuthorizationToken {token}
             
             : .\ExtractMemberEmails.ps1 -ChannelId {channel_1} -AuthorizationToken $TOKEN | .\AddMemberToChannel.ps1 -ChannelId {channel_2} -AuthorizationToken $TOKEN

             : $emailList = [System.Collections.ArrayList]@()
             : $emailList.Add("chris.blankenship@rackspace.com")
             : $emailList.Add("hai.phan@rackspace.com")
             : $emailList | .\AddMemberToChannel.ps1 -ChannelId {channel} -AuthorizationToken {token}

 Author      : chris@dscoduc.com
 Support     : https://api.slack.com
 Date        : 11/05/2020
 Version     : v1.1
# #########################################################>
[CmdletBinding(DefaultParameterSetName = "ByImportFile", SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$true, ValueFromPipeline=$True, ParameterSetName="ByUserEmail", HelpMessage="Specific user email address to add to the Slack channel")]
    [string] $UserEmail,

    [Parameter(Mandatory=$true, ParameterSetName="ByUserId", HelpMessage="Specific Slack UserID to add to the Slack channel")]
    [string] $UserId,

    [Parameter(Mandatory=$true, ParameterSetName="ByImportFile", HelpMessage="Path to import file containing list of email addresses")]
    [string] $ImportFile,

    [Parameter(Mandatory=$true, HelpMessage="Enter the Slack channel Id (e.g. C01CYQJ7ABE)")]
    [string] $ChannelId,

    [Parameter(Mandatory=$true, HelpMessage="Slack Oauth Authorization Token (e.g. xoxp-123...")]
    [string] $AuthorizationToken,

    [Parameter(Mandatory=$false, HelpMessage="Slack API base endpoint")]
    [string] $BaseUrl = "https://slack.com/api"
)
Begin {
    $Error.Clear()
    Set-StrictMode -Version Latest
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    function getSlackUserId{
        Param (
            [Parameter(Mandatory=$true)][string]$userEmail
        )
        
        ## https://api.slack.com/methods/users.lookupByEmail
        $url = "/users.lookupByEmail?token=$AuthorizationToken&email=$userEmail"
        $result = Invoke-RestMethod -Uri $BaseUrl$url
        
        if($result.ok) {
            return $result.user.id
        }
    }

    function getAllSlackUsers() {
        Write-Host "Retrieving Slack user list..."
        $maxPages = 16
        $count = 1000
        $startIndex = 1
        $slackUsers=@{}
        For ($page=0; $page -le $maxPages; $page++) {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            $result = Invoke-RestMethod -Uri "https://api.slack.com/scim/v1/Users?count=$count&startIndex=$startIndex" -Method Get -Headers @{'Authorization' = 'Bearer ' + $AuthorizationToken}

            if($result.Resources -ne $null) {    
                foreach($entry in $result.Resources) {
                    $email = $entry.emails.Item(0).value

                    try {
                        $slackUsers.Add($email, $entry.id)
                    }
                    catch [System.Management.Automation.MethodInvocationException]
                    { 
                        # Skipping duplicate entry
                    }
                }
            }
            $startIndex = $startIndex + $count
        }

        return $slackUsers
    }

    function addUserToChannel{
        [cmdletbinding(SupportsShouldProcess)]
        Param (
            [Parameter(Mandatory=$true)][string]$userId
        )

        ## https://api.slack.com/methods/conversations.invite
        $url = "/conversations.invite?token=$AuthorizationToken&channel=$ChannelId&users=$userId"

        if ($PSCmdlet.ShouldProcess("$userId", "Adding user to channel $ChannelId")) {
            $result = Invoke-RestMethod -Uri $BaseUrl$url -Method Post

            if($result.ok) {
                Write-Host "ADDED: $($userId)"
            }
            elseif($result.error -eq "already_in_channel") {
                Write-Host "SKIPPED: $($userId) already a member"
            }
            else
            {
                Write-Host -ForegroundColor Red "ERROR: $($userId) [$($result.error)]"
            }
        }
    }

    [int]$exitCode = 0
    Start-Transcript -Path "$($MyInvocation.InvocationName).log" -Force -ErrorAction SilentlyContinue | Out-Null
}
Process {

    # ByUserId Parameter Set
    if($UserId) {
        addUserToChannel -userId $UserId
    }

    # ByUserEmail Parameter Set
    elseif($UserEmail) {
        # Lookup user ID using email address
        [string]$id = getSlackUserId -userEmail $UserEmail

        if($id) {
            addUserToChannel -userId $id
        }
        else {
            Write-Host "NOTFOUND: $UserEmail not found in Slack"
            $exitCode = -1
        }

        $id = $null
    }

    # ByImportFile Parameter Set
    elseif($ImportFile) {
        $slackUsers = getAllSlackUsers
        
        if(Test-Path $ImportFile) {
            Write-Host "Importing emailentries from $ImportFile..."
            
            $emailList = Get-Content $ImportFile

            foreach($email in $emailList) {
                $slackId = $slackUsers[$email]
        
                if($slackId) {
                    addUserToChannel -userId $slackId
                    sleep -Seconds 1
                }
                else {
                    Write-Host "NOTFOUND: $email not found in Slack"
                }
            }
        }
        else {
            Write-Warning "$ImportFile not found"
            $exitCode = -1
        }
    }
}
End {
    Write-Host "Completed $($exitCode)"
    Stop-Transcript -ErrorAction SilentlyContinue | Out-Null
    exit $exitCode
}
