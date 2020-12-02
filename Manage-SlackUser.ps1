<#
.Synopsis
    Manage Slack User Accounts

.Description
    This script provides the option to enable or disable a Slack user.

.Parameter Disable
    Disable user account

.Parameter Enable
    Enable user account

.Parameter Id
    Slack User Id to manage

.Parameter AuthorizationToken
    Slack authorization token with permissions to perform the request (e.g. xoxp-123...")

.Example
    Manage-SlackUser.ps1 -Enable -Id U123456789 -AuthorizationToken $AUTHTOKEN

.Example
    Manage-SlackUser.ps1 -Disable -Id U123456789 -AuthorizationToken $AUTHTOKEN

.Example
    "U123456789","U987654321" | .\Manage-SlackUser.ps1 -Disable -AuthorizationToken $AUTHTOKEN

.Notes
    Author  : chris@dscoduc.com
    Date    : 11/17/2020
    Version : v1.0

.Link 
    https://api.slack.com/scim
#>
[CmdletBinding(DefaultParameterSetName="ByEnable", SupportsShouldProcess)]
param(
    [Parameter(Mandatory, ParameterSetName="ByEnable")]
    [switch]$Enable,

    [Parameter(Mandatory, ParameterSetName="ByDisable")]
    [switch]$Disable,

    [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [string]$Id,

    [Parameter(Mandatory, HelpMessage="Slack Oauth Authorization Token (e.g. xoxp-123...")]
    [string]$AuthorizationToken
)
Begin {
    $Error.Clear()
    Set-StrictMode -Version Latest
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    function Disable-SlackUser {
        [cmdletbinding(SupportsShouldProcess)]
        Param (
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$token,

            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$userId
        )
        
        if ($PSCmdlet.ShouldProcess("$userId", "Invoke-RestMethod -Method Delete -Uri 'https://api.slack.com/scim/v1/Users/{Id}'")) {
            Write-Verbose("Disabling $userId")

            $result = Invoke-RestMethod -Method Delete -Headers @{'Authorization' = 'Bearer ' + $token} -ContentType 'application/json' -Uri "https://api.slack.com/scim/v1/Users/$userId"
            if($result -ne $null) {
                Write-Host "$userId [Disabled]"
            }
            else
            {
                Write-Host -ForegroundColor Red "ERROR: $($userId) [$($result.error)]"
            }        
        }
    }

    function Enable-SlackUser {
        [cmdletbinding(SupportsShouldProcess)]
        Param (
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$token,

            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$userId
        )
        
        if ($PSCmdlet.ShouldProcess("$userId", "Invoke-RestMethod -Method Patch -Uri 'https://api.slack.com/scim/v1/Users/{Id}' -Body `"{'schemas': ['urn:scim:schemas:core:1.0'],'active': true}`"")) {
            Write-Verbose("Enabling $userId")
            
            $result = Invoke-RestMethod -Method Patch -Headers @{'Authorization' = 'Bearer ' + $token} -ContentType 'application/json' -Uri "https://api.slack.com/scim/v1/Users/$userId" -Body "{'schemas': ['urn:scim:schemas:core:1.0'],'active': true}"
            if($result -ne $null) {
                Write-Host "$userId [Enabled]"
            }
            else
            {
                Write-Host -ForegroundColor Red "ERROR: $($userId) [$($result.error)]"
            }
        }
    }
}
Process {
    if($Enable) {
        Enable-SlackUser -token $AuthorizationToken -userId $Id
    }
    elseif($Disable) {
        Disable-SlackUser -token $AuthorizationToken -userId $Id
    }
}
End {
    Write-Verbose "Script completed"
    Exit(0)
}
