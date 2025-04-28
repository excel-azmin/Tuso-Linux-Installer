#!/bin/bash

# Prompt the user for username and password
read -p "Enter username: " username
read -s -p "Enter password: " password  # -s flag for silent input (no display)
echo  # Add a newline for formatting

base_url="https://nms-api.arcapps.org"

# Define the API endpoint and JSON data
api_url="$base_url/tuso-api/rdpserver/login"

content_type="Content-Type: application/json"

json_data='{
  "userName": "'"$username"'",
  "password": "'"$password"'"
}'

# Make the API call using curl
response=$(curl -X POST -H "$content_type" -d "$json_data" "$api_url")

# Check if the response contains "No match found!"
if [[ "$response" == *"No match found!"* ]]; then
  echo "Incorrect Username or Password!"
  echo "Please try with a valid Username and Password."
else
    # Extract serverURL and organizationID using jq
    serverURL=$(echo "$response" | jq -r '.serverURL')
    organizationID=$(echo "$response" | jq -r '.organizationID')
    echo "Login Successfully"
    echo "organizationID: $organizationID"

    # Extract serverURL and organizationID using jq
    serverURL=$(echo "$response" | jq -r '.serverURL')
    organizationID=$(echo "$response" | jq -r '.organizationID')

    HostName=$serverURL
    Organization=$organizationID
    GUID=$(cat /proc/sys/kernel/random/uuid)
    UpdatePackagePath=""

    Args=( "$@" )
    ArgLength=${#Args[@]}

    for (( i=0; i<${ArgLength}; i+=2 ));
    do
        if [ "${Args[$i]}" = "--uninstall" ]; then
            systemctl stop remotely-agent
            rm -r -f /usr/local/bin/Remotely
            rm -f /etc/systemd/system/remotely-agent.service
            systemctl daemon-reload
            echo "Tuso Agent Uninstall Successfully"
            exit
        elif [ "${Args[$i]}" = "--path" ]; then
            UpdatePackagePath="${Args[$i+1]}"
        fi
    done

    UbuntuVersion=$(lsb_release -r -s)

    wget -q https://packages.microsoft.com/config/ubuntu/$UbuntuVersion/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
    dpkg -i packages-microsoft-prod.deb
    apt-get update
    apt-get -y install apt-transport-https
    apt-get update
    apt-get -y install dotnet-runtime-6.0
    rm packages-microsoft-prod.deb

    apt-get -y install libx11-dev
    apt-get -y install libxrandr-dev
    apt-get -y install unzip
    apt-get -y install libc6-dev
    apt-get -y install libgdiplus
    apt-get -y install libxtst-dev
    apt-get -y install xclip
    apt-get -y install jq
    apt-get -y install curl

    if [ -f "/usr/local/bin/Remotely/ConnectionInfo.json" ]; then
        SavedGUID=`cat "/usr/local/bin/Remotely/ConnectionInfo.json" | jq -r '.DeviceID'`
        if [[ "$SavedGUID" != "null" && -n "$SavedGUID" ]]; then
            GUID="$SavedGUID"
        fi
    fi

    rm -r -f /usr/local/bin/Remotely
    rm -f /etc/systemd/system/remotely-agent.service

    mkdir -p /usr/local/bin/Remotely/
    cd /usr/local/bin/Remotely/

    if [ -z "$UpdatePackagePath" ]; then
        echo  "Downloading client..." >> /tmp/Remotely_Install.log
        wget $HostName/Content/Remotely-Linux.zip
    else
        echo  "Copying install files..." >> /tmp/Remotely_Install.log
        cp "$UpdatePackagePath" /usr/local/bin/Remotely/Remotely-Linux.zip
        rm -f "$UpdatePackagePath"
    fi

    unzip ./Remotely-Linux.zip
    rm -f ./Remotely-Linux.zip
    chmod +x ./Tuso_Agent
    chmod +x ./Desktop/Remotely_Desktop

    connectionInfo="{
        \"DeviceID\":\"$GUID\", 
        \"Host\":\"$HostName\",
        \"OrganizationID\": \"$Organization\",
        \"ServerVerificationToken\":\"\"
    }"

    echo "$connectionInfo" > ./ConnectionInfo.json

    curl --head $HostName/Content/Remotely-Linux.zip | grep -i "etag" | cut -d' ' -f 2 > ./etag.txt

    echo Creating service... >> /tmp/Remotely_Install.log

    # Retrieve actual device information
    private_ip=$(ip addr show wlp0s20f3 | grep -Po 'inet \K[\d.]+')
    mac_address=$(ip link show wlp0s20f3 | awk '/ether/ {print $2}')
    motherboard_serial=$(sudo dmidecode -s baseboard-serial-number)
    public_ip=$(curl -s ifconfig.me)

    echo "your private ip : $private_ip"
    echo "your mac address: $mac_address"
    echo "your motherboard serial : $motherboard_serial"
    echo "your public ip: $public_ip"

    device_info_url="$base_url/tuso-api/rdp-device-info"
    content_type="Content-Type: application/json"

    # Use the actual device information in the payload
    payload_data='{
    "dateCreated": "2023-09-25T09:32:05.169Z",
    "createdBy": 0,
    "dateModified": "2023-09-25T09:32:05.169Z",
    "modifiedBy": 0,
    "isDeleted": false,
    "oid": 0,
    "userName": "'$username'",
    "deviceID": "'$GUID'",
    "privateIP": "'$private_ip'",
    "macAddress": "'$mac_address'",
    "motherBoardSerial": "'$motherboard_serial'",
    "publicIP": "'$public_ip'"
    }'

    request_response=$(curl -X POST -H "$content_type" -d "$payload_data" "$device_info_url")

    # Check if the response contains "Duplicate data found!"
    if [[ "$request_response" == *"Duplicate data found!"* ]]; then
    echo "User already exist! Making update user data..."
    
    # Define the PUT API endpoint and JSON data for the PUT request
    put_api_url="$base_url/tuso-api/rdp-device-info-byusername/$username"
    put_payload_data='{
    "dateCreated": "2023-09-25T09:32:05.169Z",
    "createdBy": 0,
    "dateModified": "2023-09-25T09:32:05.169Z",
    "modifiedBy": 0,
    "isDeleted": false,
    "oid": 0,
    "userName": "'$username'",
    "deviceID": "'$GUID'",
    "privateIP": "'$private_ip'",
    "macAddress": "'$mac_address'",
    "motherBoardSerial": "'$motherboard_serial'",
    "publicIP": "'$public_ip'"
    }'
    
    # Make the PUT request using curl
    put_response=$(curl -X PUT -H "$content_type" -d "$put_payload_data" "$put_api_url")
    
    else
    # Print the request response for device info
    echo "Request execute first time"
    
    fi

    serviceConfig="[Unit]
    Description=The Remotely agent used for remote access.

    [Service]
    WorkingDirectory=/usr/local/bin/Remotely/
    ExecStart=/usr/local/bin/Remotely/Tuso_Agent
    Restart=always
    StartLimitIntervalSec=0
    RestartSec=10

    [Install]
    WantedBy=graphical.target"

    echo "$serviceConfig" > /etc/systemd/system/remotely-agent.service

    sudo systemctl enable remotely-agent
    sudo systemctl restart remotely-agent

    echo Install complete. >> /tmp/Remotely_Install.log
fi