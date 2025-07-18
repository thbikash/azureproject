#!/bin/bash

# Set variables
RG="RG-WebApplication"
LOCATION="eastus"
VNET="VNet-WebApplication"
DB_SUBNET="DBSubnet"
APP_SUBNET="AppSubnet"
LB_PIP="WebApplication-LB-PublicIP"
LB_NAME="WebApplication-LB"
LB_FE="LoadBalancerFrontEnd"
LB_BE="WebApplicationBackendPool"
NSG_DB="DBNSG"
NSG_APP="AppNSG"
VM1="App-VM1"
VM2="App-VM2"
DBVM="DB-VM"
ADMIN="dbuser"

# Create Resource Group and VNet
az group create --name $RG --location $LOCATION

az network vnet create \
  --resource-group $RG \
  --name $VNET \
  --address-prefix 10.0.0.0/16 \
  --subnet-name $APP_SUBNET \
  --subnet-prefix 10.0.1.0/24

az network vnet subnet create \
  --resource-group $RG \
  --vnet-name $VNET \
  --name $DB_SUBNET \
  --address-prefix 10.0.2.0/24

# NSG for Web
az network nsg create --resource-group $RG --name $NSG_APP

az network nsg rule create --resource-group $RG --nsg-name $NSG_APP \
  --name AllowHTTP --protocol Tcp --direction Inbound --priority 100 \
  --source-address-prefixes Internet --destination-port-ranges 80 --access Allow

az network nsg rule create --resource-group $RG --nsg-name $NSG_APP \
  --name AllowSSH --protocol Tcp --direction Inbound --priority 110 \
  --source-address-prefixes Internet --destination-port-ranges 22 --access Allow

# NSG for App
az network nsg create --resource-group $RG --name $NSG_DB

az network nsg rule create --resource-group $RG --nsg-name $NSG_DB \
  --name AllowPostgresFromWeb --protocol Tcp --direction Inbound --priority 100 \
  --source-address-prefixes 10.0.1.0/24 --destination-port-ranges 5432 --access Allow

az network nsg rule create --resource-group $RG --nsg-name $NSG_DB \
  --name AllowSSHFromWeb --protocol Tcp --direction Inbound --priority 110 \
  --source-address-prefixes 10.0.1.0/24 --destination-port-ranges 22 --access Allow

# Associate NSGs
az network vnet subnet update \
  --resource-group $RG \
  --vnet-name $VNET \
  --name $APP_SUBNET \
  --network-security-group $NSG_APP

az network vnet subnet update \
  --resource-group $RG \
  --vnet-name $VNET \
  --name $DB_SUBNET \
  --network-security-group $NSG_DB

# Create App VMs
for VM in $VM1 $VM2; do
  az vm create \
    --resource-group $RG \
    --name $VM \
    --image Ubuntu2204 \
    --size Standard_B1s \
    --vnet-name $VNET \
    --subnet $APP_SUBNET \
    --admin-username $ADMIN \
    --generate-ssh-keys \
    --nsg $NSG_APP \
    --public-ip-sku Standard
done

# Create DB VM
az vm create \
  --resource-group $RG \
  --name $DBVM \
  --image Ubuntu2204 \
  --size Standard_B1s \
  --vnet-name $VNET \
  --subnet $DB_SUBNET \
  --admin-username $ADMIN \
  --generate-ssh-keys \
  --public-ip-address ""

# Create Load Balancer
az network public-ip create \
  --resource-group $RG \
  --name $LB_PIP \
  --sku Standard --allocation-method Static

az network lb create \
  --resource-group $RG \
  --name $LB_NAME \
  --public-ip-address $LB_PIP \
  --frontend-ip-name $LB_FE \
  --backend-pool-name $LB_BE

az network lb probe create \
  --resource-group $RG \
  --lb-name $LB_NAME \
  --name httpProbe \
  --protocol tcp \
  --port 80

az network lb rule create \
  --resource-group $RG \
  --lb-name $LB_NAME \
  --name httpRule \
  --protocol tcp \
  --frontend-port 80 \
  --backend-port 80 \
  --frontend-ip-name $LB_FE \
  --backend-pool-name $LB_BE \
  --probe-name httpProbe

# Dynamically get NICs for App VMs
APP_NICS=$(az network nic list --resource-group $RG \
  --query "[?contains(name, 'App-VM')].[name]" -o tsv)

# Loop through each NIC and get its IP config name
for NIC in $APP_NICS; do
  IPCONFIG=$(az network nic show \
    --resource-group $RG \
    --name $NIC \
    --query "ipConfigurations[0].name" -o tsv)

  echo "🔧 Attaching $NIC (IP Config: $IPCONFIG) to backend pool..."

az network nic ip-config address-pool add \
    --address-pool $LB_BE \
    --ip-config-name $IPCONFIG \
    --nic-name $NIC \
    --resource-group $RG \
    --lb-name $LB_NAME
done



echo ""
echo "Azure deployment completed. Manual steps remaining:"
echo "1. SSH into App-VM1 & App-VM2 to set up Flask app."
echo "2. Reset SSH public key for DB-VM via Azure Portal." 
echo "3. SSH into DB-VM from App-VM1 to install PostgreSQL and create DB."
echo "4. Open your browser: http://$(az network public-ip show --resource-group $RG --name $LB_PIP --query ipAddress -o tsv)"

