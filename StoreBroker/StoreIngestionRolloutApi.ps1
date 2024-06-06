# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

Add-Type -TypeDefinition @"
   public enum StoreBrokerRolloutProperty
   {
       isEnabled,
       isSeekEnabled,
       percentage,
       resourceType,
       revisionToken,
       state
   }
"@

Add-Type -TypeDefinition @"
   public enum StoreBrokerRolloutState
   {
       Initialized,
       Completed,
       RolledBack
   }
"@

function Get-SubmissionRollout
{
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({if ($_.Length -le 12) { throw "It looks like you supplied an AppId instead of a ProductId.  Use Get-Product with -AppId to find the ProductId for this AppId." } else { $true }})]
        [string] $ProductId,

        [Parameter(Mandatory)]
        [string] $SubmissionId,

        [string] $ClientRequestId,

        [string] $AccessToken,

        [switch] $NoStatus
    )

    Write-InvocationLog

    try
    {
        $telemetryProperties = @{
            [StoreBrokerTelemetryProperty]::ProductId = $ProductId
            [StoreBrokerTelemetryProperty]::SubmissionId = $SubmissionId
            [StoreBrokerTelemetryProperty]::ClientRequestId = $ClientRequestId
        }

        $params = @{
            "UriFragment" = "products/$ProductId/submissions/$SubmissionId/rollout"
            "Method" = 'Get'
            "Description" = "Getting rollout info for product: $ProductId submissionId: $SubmissionId"
            "ClientRequestId" = $ClientRequestId
            "AccessToken" = $AccessToken
            "TelemetryEventName" = "Get-SubmissionRollout"
            "TelemetryProperties" = $telemetryProperties
            "NoStatus" = $NoStatus
        }

        return Invoke-SBRestMethod @params
    }
    catch
    {
        throw
    }
}

function Set-SubmissionRollout
{
    [CmdletBinding(
        SupportsShouldProcess,
        DefaultParametersetName="Object")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({if ($_.Length -le 12) { throw "It looks like you supplied an AppId instead of a ProductId.  Use Get-Product with -AppId to find the ProductId for this AppId." } else { $true }})]
        [string] $ProductId,

        [Parameter(Mandatory)]
        [string] $SubmissionId,

        [Parameter(
            Mandatory,
            ParameterSetName="Object")]
        [PSCustomObject] $Object,

        [Parameter(ParameterSetName="Individual")]
        [ValidateSet('Initialized', 'Completed', 'RolledBack')]
        [string] $State = 'Initialized',

        [Parameter(ParameterSetName="Individual")]
        [ValidateRange(0, 100)]
        [float] $Percentage,

        [Parameter(ParameterSetName="Individual")]
        [switch] $Enabled,

        [Parameter(ParameterSetName="Individual")]
        [switch] $SeekEnabled,

        [string] $ClientRequestId,

        [string] $AccessToken,

        [switch] $NoStatus
    )

    Write-InvocationLog

    try
    {
        $telemetryProperties = @{
            [StoreBrokerTelemetryProperty]::ProductId = $ProductId
            [StoreBrokerTelemetryProperty]::SubmissionId = $SubmissionId
            [StoreBrokerTelemetryProperty]::UsingObject = ($null -ne $Object)
            [StoreBrokerTelemetryProperty]::State = $State
            [StoreBrokerTelemetryProperty]::ClientRequestId = $ClientRequestId
        }

        Test-ResourceType -Object $Object -ResourceType ([StoreBrokerResourceType]::Rollout)

        $hashBody = $Object
        if ($null -eq $hashBody)
        {
            # Convert the input into a Json body.
            $hashBody = @{}
            $hashBody[[StoreBrokerRolloutProperty]::resourceType] = [StoreBrokerResourceType]::Rollout
            $hashBody[[StoreBrokerRolloutProperty]::state] = $State

            if ($PSBoundParameters.ContainsKey('Percentage'))
            {
                $hashBody[[StoreBrokerRolloutProperty]::percentage] = $Percentage
                $telemetryProperties[[StoreBrokerTelemetryProperty]::Percentage] = $Percentage
            }

            # We only set the value if the user explicitly provided a value for this parameter
            # (so for $false, they'd have to pass in -Enabled:$false).
            # Otherwise, there'd be no way to know when the user wants to simply keep the
            # existing value.
            if ($PSBoundParameters.ContainsKey('Enabled'))
            {
                $hashBody[[StoreBrokerRolloutProperty]::isEnabled] = ($Enabled -eq $true)
                $telemetryProperties[[StoreBrokerTelemetryProperty]::IsEnabled] = ($Enabled -eq $true)
            }

            # We only set the value if the user explicitly provided a value for this parameter
            # (so for $false, they'd have to pass in -SeekEnabled:$false).
            # Otherwise, there'd be no way to know when the user wants to simply keep the
            # existing value.
            if ($PSBoundParameters.ContainsKey('SeekEnabled'))
            {
                $hashBody[[StoreBrokerRolloutProperty]::isSeekEnabled] = ($SeekEnabled -eq $true)
                $telemetryProperties[[StoreBrokerTelemetryProperty]::IsSeekEnabled] = ($SeekEnabled -eq $true)
            }
        }

        $body = Get-JsonBody -InputObject $hashBody
        Write-Body -InputObject $hashBody

        $params = @{
            "UriFragment" = "products/$ProductId/submissions/$SubmissionId/rollout"
            "Method" = 'Post'
            "Description" = "Updating rollout details for submission: $SubmissionId"
            "Body" = $body
            "ClientRequestId" = $ClientRequestId
            "AccessToken" = $AccessToken
            "TelemetryEventName" = "Set-SubmissionRollout"
            "TelemetryProperties" = $telemetryProperties
            "NoStatus" = $NoStatus
        }

        $result = (Invoke-SBRestMethod @params)

        # TODO: Verify that this is still true with the v2 API
        if (($result.percentage -eq 100) -and ($result.state -ne [StoreBrokerRolloutState]::Completed))
        {
            Write-Log -Level Warning -Message @(
                "Changing the rollout percentage to 100% does not ensure that all of your customers will get the",
                "packages from the latest submissions, because some customers may be on OS versions that don't",
                "support rollout. You must finalize the rollout in order to stop distributing the older packages",
                "and update all existing customers to the newer ones by calling",
                "    Set-SubmissionRollout -ProductId $ProductId -SubmissionId $SubmissionId -State Completed")
        }
        elseif (($result.percentage -ge 0) -and ($result.state -eq [StoreBrokerRolloutState]::Initialized))
        {
            Write-Log -Level Warning -Message @(
                "Your rollout selections apply to all of your packages, but will only apply to your customers running OS",
                "versions that support package flights (Windows.Desktop build 10586 or later; Windows.Mobile build 10586.63",
                "or later, and Xbox), including any customers who get the app via Store-managed licensing via the",
                "Windows Store for Business.  When using gradual package rollout, customers on earlier OS versions will not",
                "get packages from the latest submission until you finalize the package rollout.")
        }

        return $result
    }
    catch
    {
        throw
    }
}

function Update-SubmissionRollout
{
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [Parameter(Mandatory)]
        [string] $ProductId,

        [Parameter(Mandatory)]
        [string] $SubmissionId,

        [ValidateSet('Initialized', 'Completed', 'RolledBack')]
        [string] $State = 'Initialized',

        [ValidateRange(0, 100)]
        [float] $Percentage,

        [switch] $Enabled,

        [switch] $SeekEnabled,

        [string] $ClientRequestId,

        [string] $AccessToken,

        [switch] $NoStatus
    )

    Write-InvocationLog

    try
    {
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

        $params = @{
            'ProductId' = $ProductId
            'SubmissionId' = $SubmissionId
            'ClientRequestId' = $ClientRequestId
            'AccessToken' = $AccessToken
            'NoStatus' = $NoStatus
        }

        $rollout = Get-SubmissionRollout @params

        Set-ObjectProperty -InputObject $rollout -Name ([StoreBrokerRolloutProperty]::state) -Value $State

        if ($PSBoundParameters.ContainsKey('Percentage'))
        {
            Set-ObjectProperty -InputObject $rollout -Name ([StoreBrokerRolloutProperty]::percentage) -Value $Percentage
        }

        # We only set the value if the user explicitly provided a value for this parameter
        # (so for $false, they'd have to pass in -Enabled:$false).
        # Otherwise, there'd be no way to know when the user wants to simply keep the
        # existing value.
        if ($PSBoundParameters.ContainsKey('Enabled'))
        {
            Set-ObjectProperty -InputObject $rollout -Name ([StoreBrokerRolloutProperty]::isEnabled) -Value ($Enabled -eq $true)
        }

        # We only set the value if the user explicitly provided a value for this parameter
        # (so for $false, they'd have to pass in -SeekEnabled:$false).
        # Otherwise, there'd be no way to know when the user wants to simply keep the
        # existing value.
        if ($PSBoundParameters.ContainsKey('SeekEnabled'))
        {
            Set-ObjectProperty -InputObject $rollout -Name ([StoreBrokerRolloutProperty]::isSeekEnabled) -Value ($SeekEnabled -eq $true)
        }

        $null = Set-SubmissionRollout @params -Object $rollout

        # Record the telemetry for this event.
        $stopwatch.Stop()
        $telemetryMetrics = @{ [StoreBrokerTelemetryMetric]::Duration = $stopwatch.Elapsed.TotalSeconds }
        $telemetryProperties = @{
            [StoreBrokerTelemetryProperty]::ProductId = $ProductId
            [StoreBrokerTelemetryProperty]::SubmissionId = $SubmissionId
            [StoreBrokerTelemetryProperty]::Percentage = $Percentage
            [StoreBrokerTelemetryProperty]::ClientRequestId = $ClientRequestId
        }

        if (-not [String]::IsNullOrWhiteSpace($global:SBStoreBrokerClientName)) { $telemetryProperties[[StoreBrokerTelemetryProperty]::ClientName] = $global:SBStoreBrokerClientName }

        Set-TelemetryEvent -EventName Update-SubmissionRollout -Properties $telemetryProperties -Metrics $telemetryMetrics
        return
    }
    catch
    {
        throw
    }
}
