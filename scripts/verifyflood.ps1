########################################################################################################
#
# verifyflood.ps1
#
# Created by jason@flood.io (Jason Rizio) - 11th September 2019
#
# Description: A PowerShell script that will verify a Grid is created, a Flood is executed and
# a simple load testing SLA is met.
#
########################################################################################################

#Declare some variables and input parameters
$access_token = $env:MY_FLOOD_TOKEN
$flood_uuid = $env:MY_FLOOD_UUID
$api_url = "https://api.flood.io"

#Encode the Flood auth token with Base64 and use it as a header for our request to Flood API
$bytes = [System.Text.Encoding]::ASCII.GetBytes($access_token)
$base64 = [System.Convert]::ToBase64String($bytes)
$basicAuthValue = "Basic $base64"
$headers = @{
    'Authorization' = $basicAuthValue
}

#Retrieve the Grid ID that we will be using.
try {
    
    $uri = "$api_url/floods/$flood_uuid"
    $responseGrid = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers
    $outGridID = $responseGrid._embedded.grids[0].uuid
    Write-Output ">> Grid ID is: $outGridID"

}
catch {
    $responseBody = ""
    $errorMessage = $_.Exception.Message
    if (Get-Member -InputObject $_.Exception -Name 'Response') {
        write-output $_.Exception.Response
       
        try {
            $result = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($result, [System.Text.Encoding]::ASCII)
            $reader.BaseStream.Position = 0
            $reader.DiscardBufferedData()
            $responseBody = $reader.ReadToEnd();
            Write-Output "response body: $responseBody"
        }
        catch {
            Throw "An error occurred while calling REST method at: $uri. Error: $errorMessage. Cannot get more information."
        }
    }
    Throw "An error occurred while calling REST method at: $uri. Error: $errorMessage. Response body: $responseBody"

}

#Wait for the Grid load generation infrastructure to start
write-output ">> Waiting for Grid ($outGridID) to start ..."
do{

    $uri = "$api_url/grids/$outGridID"
    $responseStatus1 = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers
    $currentGridStatus = $responseStatus1.status

    if($currentGridStatus -eq "started"){
        write-output ">> The Grid has successfully started."
    }

    if($currentGridStatus -eq "starting"){
        Start-Sleep -Seconds 10
    }

}while($currentGridStatus -eq "starting")

#Wait for the Flood to start from the QUEUED status successfully
write-output ">> Waiting for the Flood ($flood_uuid) to start ..."
do{

    $uri = "$api_url/floods/$flood_uuid"
    $responseStatus = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers
    $currentFloodStatus = $responseStatus.status

    if($currentFloodStatus -eq "running"){
        write-output ">> The Flood has started."
    }

    if($currentFloodStatus -eq "queued"){
        Start-Sleep -Seconds 10
    }

}while($currentFloodStatus -eq "queued")

#Wait for the Flood to complete and be in FINISHED status.
write-output ">> Waiting for the Flood ($flood_uuid) to complete ..."
do{

    $uri = "$api_url/floods/$flood_uuid"
    $responseStatus = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers
    $currentFloodStatus = $responseStatus.status

    if($currentFloodStatus -eq "finished"){
        write-output ">> The Flood has finished."
    }

    if($currentFloodStatus -eq "running"){
        Start-Sleep -Seconds 10
    }

}while($currentFloodStatus -eq "running")

#Retrieve the mean error rate for the Flood to use for our simple SLA verification.
try {
    
    $uri = "$api_url/floods/$flood_uuid/report"
    $responseReport = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers
    $outMeanErrorRate = $responseReport.mean_error_rate
    Write-Output ">> Mean Error Rate is: $outMeanErrorRate"

}
catch {
    $responseBody = ""
    $errorMessage = $_.Exception.Message
    if (Get-Member -InputObject $_.Exception -Name 'Response') {
        write-output $_.Exception.Response
       
        try {
            $result = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($result, [System.Text.Encoding]::ASCII)
            $reader.BaseStream.Position = 0
            $reader.DiscardBufferedData()
            $responseBody = $reader.ReadToEnd();
            Write-Output "response body: $responseBody"
        }
        catch {
            Throw "An error occurred while calling REST method at: $uri. Error: $errorMessage. Cannot get more information."
        }
    }
    Throw "An error occurred while calling REST method at: $uri. Error: $errorMessage. Response body: $responseBody"

}

#Our SLA SUCCESS criteria is that no errors are observed for this test.
if($outMeanErrorRate -eq "0"){
    write-output ">> SUCCESS - the Flood returned no errors or failed transactions."
}
else {
    Write-Error ">> FAILED - the Flood returned errors or failed transactions."
}

