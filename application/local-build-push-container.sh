#!/bin/bash
# You have to login and select your default subscription to azure befor using this script: 
# az login
# az account set --subscription "<your_subscription>" 
containerRegistryName="acrtodosample" #TODO: set your container registry name
containerRegistryUser="$containerRegistryName"
containerImageName="app-todo-sample"  
azureContainerRegistry="$containerRegistryName.azurecr.io"
resourceGroup="rg-todo-sample"        #TODO: set your resource group
containerPassword=$(az acr credential show --resource-group $resourceGroup --name $containerRegistryName --query passwords[0].value -o tsv)

echo "Build image and push to $azureContainerRegistry"

echo "Building the container..."
docker build -t $containerImageName:local .
echo

echo "Tagging for azure container registry"
docker tag $containerImageName:local $azureContainerRegistry/$containerImageName:local
echo

echo "Push image"
docker push $azureContainerRegistry/$containerImageName:local
echo

echo "Repositories in the container registry"
az acr repository list -n $containerRegistryName
