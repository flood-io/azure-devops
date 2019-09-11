#!/bin/bash

# Based on flood-run-e2e.sh in https://github.com/wilsonmar/DevSecOps/tree/master/flood-io
# from https://docs.flood.io/#end-to-end-example retrieved 8 July 2019.
# to launch and run flood tests.
# Written by WilsonMar@gmail.com

# sh -c "$(curl -fsSL https://raw.githubusercontent.com/wilsonmar/DevSecOps/master/flood-io/flood-run-e2e.sh)"

# This is free software; see the source for copying conditions. There is NO
# warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

set -e  # exit script if any command returnes a non-zero exit code.
# set -x  # display every command.

echo -e ">>> MY_FLOOD_TOKEN is: $MY_FLOOD_TOKEN"
echo -e ">>> MY_FLOOD_UUID is: $MY_FLOOD_UUID"
echo -e ">>> FLOOD_USERNAME is: $FLOOD_USERNAME"
echo -e ">>> FLOOD_PASSWORD is: $FLOOD_PASSWORD"

#function write to stderr if we need to report a fail
echoerr() { echo "$@" 1>&2; }

FLOOD_SLEEP_SECS="10"
FLOOD_USER=$MY_FLOOD_TOKEN+":x"

# PROTIP: use environment variables to pass links to where the secret is really stored: use an additional layer of indirection.
# From https://app.flood.io/account/user/security
if [ -z "$MY_FLOOD_TOKEN" ]; then
   echo -e "\n>>> MY_FLOOD_TOKEN not available. Exiting..."
   exit 9
else
   echo -e "\n>>> MY_FLOOD_TOKEN available. Continuing..."
fi
## To sign into https://app.flood.io/account/user/security (API Access)
if [ -z "$FLOOD_USER" ]; then
   echo -e "\n>>> FLOOD_USER not available. Exiting..."
   exit 9
else
   echo -e "\n>>> FLOOD_USER available. Continuing..."
fi

   #Login=$(curl -X POST https://api.flood.io/oauth/token -F 'grant_type=password' -F 'username=$FLOOD_USERNAME' -F 'password=$FLOOD_PASSWORD') #required username and password
   #echo -e "Login: $Login"

   #Token=$(echo $Login | jq -r '.access_token')
   #Patch=$(curl -X PATCH https://api.flood.io/api/v3/floods/$MY_FLOOD_UUID/set-public -H 'Authorization: Bearer '$Token -H 'Content-Type: application/json')

   #echo -e "Token: $Token"
   #echo -e "Patch: $Patch"

   #display Grid status
   echo -e "\n>>> [$(date +%FT%T)+00:00] Checking Grid status ... "
   grid_uuid=$(curl --silent --user $MY_FLOOD_TOKEN: -X GET https://api.flood.io/floods/$MY_FLOOD_UUID | jq -r "._embedded.grids[0].uuid" )
   echo -e "\n>>> [$(date +%FT%T)+00:00] Grid UUID: $grid_uuid"
   echo -e "\n>>> [$(date +%FT%T)+00:00] Waiting for Grid to become available ..."
   while [ $(curl --silent --user $MY_FLOOD_TOKEN: -X GET https://api.flood.io/grids/$grid_uuid | jq -r '.status == "started"') = "false" ]; do
     sleep "$FLOOD_SLEEP_SECS"
   done

   #display Flood status
   echo -e "\n>>> [$(date +%FT%T)+00:00] Flood is currently running ... waiting until finished ..."
   while [ $(curl --silent --user $MY_FLOOD_TOKEN: -X GET https://api.flood.io/floods/$MY_FLOOD_UUID | jq -r '.status == "finished"') = "false" ]; do
     sleep "$FLOOD_SLEEP_SECS"
   done

   echo -e "\n>>> [$(date +%FT%T)+00:00] Flood has finished ... Getting the summary report ..."
   flood_report=$(curl --silent --user $MY_FLOOD_TOKEN:  -X GET https://api.flood.io/floods/$MY_FLOOD_UUID/report \
       | jq -r ".summary" )
   
   #mean_error_rate
   flood_error_rate=$(curl --silent --user $MY_FLOOD_TOKEN:  -X GET https://api.flood.io/floods/$MY_FLOOD_UUID/report \
       | jq -r ".mean_error_rate" )

   #echo -e "\n>>> [$(date +%FT%T)+00:00] Detailed results at https://api.flood.io/floods/$MY_FLOOD_UUID"

   echo "Flood Summary Report: $flood_report"  # summary report
   echo "Flood Mean Error Rate: $flood_error_rate"  # summary report

   #verify our SLA for 0 failed transactions
   if [ `echo $flood_error_rate | grep -c "0" ` -gt 0 ]
   then
     echo "FLOOD PASSED: The Flood ran with 0 Failed transactions." 
   else
     echoerr "FLOOD FAILED: The Flood encountered Failed transactions."
   fi



#done



