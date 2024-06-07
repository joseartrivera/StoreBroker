# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

Add-Type -TypeDefinition @"
   public enum StoreBrokerFlightProperty
   {
       name,
       groupIds,
       relativeRank,
       resourceType,
       revisionToken,
       type
   }
"@

Add-Type -TypeDefinition @"
   public enum StoreBrokerFlightTypeProperty
   {
       packageFlight
   }
"@

function Get-Flight
{
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({if ($_.Length -le 12) { throw "It looks like you supplied an AppId instead of a ProductId.  Use Get-Product with -AppId to find the ProductId for this AppId." } else { $true }})]
        [string] $ProductId,

        [string] $FlightId,

        [switch] $SinglePage,

        [string] $ClientRequestId,

        [string] $AccessToken,

        [switch] $NoStatus
    )

    Write-InvocationLog

    try
    {
        $singleQuery = (-not [String]::IsNullOrWhiteSpace($FlightId))
        $telemetryProperties = @{
            [StoreBrokerTelemetryProperty]::ProductId = $ProductId
            [StoreBrokerTelemetryProperty]::FlightId = $FlightId
            [StoreBrokerTelemetryProperty]::SingleQuery = $singleQuery
            [StoreBrokerTelemetryProperty]::ClientRequestId = $ClientRequestId
        }

        $params = @{
            "ClientRequestId" = $ClientRequestId
            "AccessToken" = $AccessToken
            "TelemetryEventName" = "Get-Flight"
            "TelemetryProperties" = $telemetryProperties
            "NoStatus" = $NoStatus
        }

        if ($singleQuery)
        {
            $params["UriFragment"] = "products/$ProductId/flights/$FlightId"
            $params["Method" ] = 'Get'
            $params["Description"] =  "Getting flight $FlightId for $ProductId"

            return Invoke-SBRestMethod @params
        }
        else
        {
            $params["UriFragment"] = "products/$ProductId/flights"
            $params["Description"] =  "Getting flights for $ProductId"
            $params["SinglePage" ] = $SinglePage

            return Invoke-SBRestMethodMultipleResult @params
        }
    }
    catch
    {
        throw
    }
}

function New-Flight
{
    [CmdletBinding(
        SupportsShouldProcess,
        DefaultParametersetName="Object")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({if ($_.Length -le 12) { throw "It looks like you supplied an AppId instead of a ProductId.  Use Get-Product with -AppId to find the ProductId for this AppId." } else { $true }})]
        [string] $ProductId,

        [Parameter(
            Mandatory,
            ParameterSetName="Object")]
        [PSCustomObject] $Object,

        [Parameter(
            Mandatory,
            ParameterSetName="Individual")]
        [string] $Name,

        [Parameter(
            Mandatory,
            ParameterSetName="Individual")]
        [string[]] $GroupId,

        [Parameter(ParameterSetName="Individual")]
        [int] $RelativeRank,

        [string] $ClientRequestId,

        [string] $AccessToken,

        [switch] $NoStatus
    )

    Write-InvocationLog

    try
    {
        $telemetryProperties = @{
            [StoreBrokerTelemetryProperty]::ProductId = $ProductId
            [StoreBrokerTelemetryProperty]::UsingObject = ($null -ne $Object)
            [StoreBrokerTelemetryProperty]::RelativeRank = $RelativeRank
            [StoreBrokerTelemetryProperty]::ClientRequestId = $ClientRequestId
        }

        Test-ResourceType -Object $Object -ResourceType ([StoreBrokerResourceType]::Flight)

        $hashBody = $Object
        if ($null -eq $hashBody)
        {
            # Convert the input into a Json body.
            $hashBody = @{}
            $hashBody[[StoreBrokerFlightProperty]::resourceType] = [StoreBrokerResourceType]::Flight
            $hashBody[[StoreBrokerFlightProperty]::type] = [StoreBrokerFlightTypeProperty]::packageFlight
            $hashBody[[StoreBrokerFlightProperty]::name] = $Name
            $hashBody[[StoreBrokerFlightProperty]::groupIds] = @($GroupId)

            if ($PSBoundParameters.ContainsKey('RelativeRank'))
            {
                $hashBody[[StoreBrokerFlightProperty]::relativeRank] = $RelativeRank
            }
        }

        $body = Get-JsonBody -InputObject $hashBody
        Write-InputObject -InputObject $hashBody

        $params = @{
            "UriFragment" = "products/$ProductId/flights"
            "Method" = 'Post'
            "Description" = "Creating new flight for $ProductId"
            "Body" = $body
            "ClientRequestId" = $ClientRequestId
            "AccessToken" = $AccessToken
            "TelemetryEventName" = "New-Flight"
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

function Remove-Flight
{
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    [Alias("Delete-Flight")]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({if ($_.Length -le 12) { throw "It looks like you supplied an AppId instead of a ProductId.  Use Get-Product with -AppId to find the ProductId for this AppId." } else { $true }})]
        [string] $ProductId,

        [Parameter(Mandatory)]
        [string] $FlightId,

        [string] $ClientRequestId,

        [string] $AccessToken,

        [switch] $NoStatus
    )

    Write-InvocationLog

    try
    {
        $telemetryProperties = @{
            [StoreBrokerTelemetryProperty]::ProductId = $ProductId
            [StoreBrokerTelemetryProperty]::FlightId = $FlightId
            [StoreBrokerTelemetryProperty]::ClientRequestId = $ClientRequestId
        }

        $params = @{
            "UriFragment" = "products/$ProductId/flights/$FlightId"
            "Method" = "Delete"
            "Description" = "Deleting flight $FlightId for $ProductId"
            "ClientRequestId" = $ClientRequestId
            "AccessToken" = $AccessToken
            "TelemetryEventName" = "Remove-Flight"
            "TelemetryProperties" = $telemetryProperties
            "NoStatus" = $NoStatus
        }

        $null = Invoke-SBRestMethod @params
    }
    catch
    {
        throw
    }
}

function Set-Flight
{
    [CmdletBinding(
        SupportsShouldProcess,
        DefaultParametersetName="Object")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({if ($_.Length -le 12) { throw "It looks like you supplied an AppId instead of a ProductId.  Use Get-Product with -AppId to find the ProductId for this AppId." } else { $true }})]
        [string] $ProductId,

        [Parameter(
            Mandatory,
            ParameterSetName="Individual")]
        [Parameter(ParameterSetName="Object")]
        [string] $FlightId,

        [Parameter(
            Mandatory,
            ParameterSetName="Object")]
        [PSCustomObject] $Object,

        [Parameter(
            Mandatory,
            ParameterSetName="Individual")]
        [string] $Name,

        [Parameter(
            Mandatory,
            ParameterSetName="Individual")]
        [string[]] $GroupId,

        [Parameter(ParameterSetName="Individual")]
        [int] $RelativeRank,

        [Parameter(
            Mandatory,
            ParameterSetName="Individual")]
        [string] $RevisionToken,

        [string] $ClientRequestId,

        [string] $AccessToken,

        [switch] $NoStatus
    )

    Write-InvocationLog

    try
    {
        if ($null -ne $Object)
        {
            $FlightId = $Object.id
        }

        $telemetryProperties = @{
            [StoreBrokerTelemetryProperty]::ProductId = $ProductId
            [StoreBrokerTelemetryProperty]::FlightId = $FlightId
            [StoreBrokerTelemetryProperty]::UsingObject = ($null -ne $Object)
            [StoreBrokerTelemetryProperty]::RelativeRank = $RelativeRank
            [StoreBrokerTelemetryProperty]::RevisionToken = $RevisionToken
            [StoreBrokerTelemetryProperty]::ClientRequestId = $ClientRequestId
        }

        Test-ResourceType -Object $Object -ResourceType ([StoreBrokerResourceType]::Flight)

        $hashBody = $Object
        if ($null -eq $hashBody)
        {
            # Convert the input into a Json body.
            $hashBody = @{}
            $hashBody[[StoreBrokerFlightProperty]::resourceType] = [StoreBrokerResourceType]::Flight
            $hashBody[[StoreBrokerFlightProperty]::type] = [StoreBrokerFlightTypeProperty]::packageFlight
            $hashBody[[StoreBrokerFlightProperty]::name] = $Name
            $hashBody[[StoreBrokerFlightProperty]::groupIds] = @($GroupId)
            $hashBody[[StoreBrokerFlightProperty]::revisionToken] = $RevisionToken

            if ($PSBoundParameters.ContainsKey('RelativeRank'))
            {
                $hashBody[[StoreBrokerFlightProperty]::relativeRank] = $RelativeRank
            }
        }

        $body = Get-JsonBody -InputObject $hashBody
        Write-InputObject -InputObject $hashBody

        $params = @{
            "UriFragment" = "products/$ProductId/flights/$FlightId"
            "Method" = 'Put'
            "Description" = "Updating flight $FlightId for $ProductId"
            "Body" = $body
            "ClientRequestId" = $ClientRequestId
            "AccessToken" = $AccessToken
            "TelemetryEventName" = "Set-Flight"
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

function Update-Flight
{
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param(
        [Parameter(Mandatory)]
        [string] $ProductId,

        [Parameter(Mandatory)]
        [string] $FlightId,

        [string] $Name,

        [string[]] $GroupId,

        [int] $RelativeRank,

        [string] $ClientRequestId,

        [string] $AccessToken,

        [switch] $NoStatus
    )

    Write-InvocationLog

    try
    {
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

        $ClientRequestId = Get-ClientRequestId -ClientRequestId $ClientRequestId -Identifier 'Update-Flight'

        $params = @{
            'ProductId' = $ProductId
            'FlightId' = $FlightId
            'ClientRequestId' = $ClientRequestId
            'AccessToken' = $AccessToken
            'NoStatus' = $NoStatus
        }

        $flight = Get-Flight @params

        if ($PSBoundParameters.ContainsKey('Name'))
        {
            Set-ObjectProperty -InputObject $flight -Name ([StoreBrokerFlightProperty]::name) -Value $Name
        }

        if ($PSBoundParameters.ContainsKey('GroupId'))
        {
            Set-ObjectProperty -InputObject $flight -Name ([StoreBrokerFlightProperty]::groupIds) -Value @($GroupId)
        }

        if ($PSBoundParameters.ContainsKey('RelativeRank'))
        {
            Set-ObjectProperty -InputObject $flight -Name ([StoreBrokerFlightProperty]::relativeRank) -Value $RelativeRank
        }

        $null = Set-Flight @params -Object $flight

        # Record the telemetry for this event.
        $stopwatch.Stop()
        $telemetryMetrics = @{ [StoreBrokerTelemetryMetric]::Duration = $stopwatch.Elapsed.TotalSeconds }
        $telemetryProperties = @{
            [StoreBrokerTelemetryProperty]::ProductId = $ProductId
            [StoreBrokerTelemetryProperty]::FlightId = $FlightId
            [StoreBrokerTelemetryProperty]::ClientRequestId = $ClientRequestId
        }

        Set-TelemetryEvent -EventName Update-Flight -Properties $telemetryProperties -Metrics $telemetryMetrics
        return
    }
    catch
    {
        throw
    }
}
