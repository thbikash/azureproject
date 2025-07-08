Virtual Machine
=======================

1. azuredeploy.json >> Basic ARM template to create VM.

2. azuredeploycustomconfiguration.json >> ARM template creates VM, NSG (port 22 and 80), Custom Config to install/start NGINX


Resource Group
=====================

1. resourceGroup.json >> ARM Template to create Resource Group.

Storage Account
===================

1. createStorageAccount.json >> ARM Template to create Storage Account.

App Services
================


WorkFlows ( GitHubAction Deployment )
=======================================
1. deploy-arm.yml >> Simple YML file calls ARM to create VM through Github Action Pipeline.

2. deploy-vm-chain.yml >> YML file calls ARM to create Resource Group first and then create Custom Configuration VM through Github Action Pipeline.

3. deploy-rg.yml >> This YML file will be called by deploy-vm-chain.yml to create resource group.

4. deploy-resource-group.yml >> YML file calls ARM to create Resource Group through Github Action Pipeline.

5. deploy-storage.yml >> YML file calls ARM to create Storage Account through Github Action Pipeline.

6. main_training1webapp1.yml >> YML to create App Service through Github Action Pipeline.







