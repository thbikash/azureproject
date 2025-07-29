@description('Name of the virtual machine')
param vmName string

@description('Admin username for the VM')
param adminUsername string = 'azureuser'

@description('Admin password for the VM')
@secure()
param adminPassword string

@description('Size of the VM')
param vmSize string = 'Standard_B1s' // ✅ Changed to free tier eligible

@description('Location for all resources')
param location string = resourceGroup().location

// Network Security Group
resource vmName_nsg 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: '${vmName}-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-SSH'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1000
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow-HTTP'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1100
          direction: 'Inbound'
        }
      }
    ]
  }
}

// Virtual Network + Subnet
resource name_vnet 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: '${resourceGroup().name}-vnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: '10.0.0.0/24'
          networkSecurityGroup: {
            id: vmName_nsg.id
          }
        }
      }
    ]
  }
}

// NIC without Public IP (Free)
resource vmName_nic 'Microsoft.Network/networkInterfaces@2021-02-01' = {
  name: '${vmName}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', '${resourceGroup().name}-vnet', 'default')
          }
          // ✅ No public IP (to avoid cost)
        }
      }
    ]
  }
  dependsOn: [
    name_vnet
  ]
}

// Virtual Machine
resource vm 'Microsoft.Compute/virtualMachines@2021-07-01' = {
  name: vmName
  location: location
  tags: {
    AutoShutdown: 'Enabled' // Optional tag for auto-shutdown
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'UbuntuServer'
        sku: '18.04-LTS'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS' // ✅ Cheapest disk
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: vmName_nic.id
        }
      ]
    }
  }
}

// Custom Script to Install Nginx
resource vmName_nginxInstall 'Microsoft.Compute/virtualMachines/extensions@2021-03-01' = {
  parent: vm
  name: 'nginxInstall'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: []
      commandToExecute: 'apt-get update && apt-get install -y nginx && systemctl start nginx'
    }
  }
}

output adminUsername string = adminUsername
output vmName string = vmName
