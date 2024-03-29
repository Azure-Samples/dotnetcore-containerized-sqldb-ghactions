---
page_type: sample
description: "Deploy containerized dotnet application using GitHub Actions"
products:
- GitHub Actions
- Web App for Containers
- Azure SQL Database
languages:
- dotnet
---

# Containerized ASP.NET Core and Azure SQL db for GitHub Actions

This is repo contains a sample ASP.NET Core application which uses an Azure SQL database as backend. The web app is containerized and deployed to Azure Web Apps for Containers using by using GitHub Actions.

For all samples to set up GitHub workflows, see [Create your first workflow](https://github.com/Azure/actions-workflow-samples)

The sample source code is based in the tutorial for building [ASP.NET Core and Azure SQL Database app in App Services](https://docs.microsoft.com/azure/app-service/containers/tutorial-dotnetcore-sqldb-app). 

## Setup an end-to-end CI/CD workflow

This repo contains two different GitHub workflows:
* [Create Azure Resources](.github/workflows/azuredeploy.yaml): To create the Azure Resources required for the sample by using an ARM template. This workflow will create the following resources:
    - App Service Plan (Linux).
    - Web App for Containers (with one staging slot)
    - Azure Container Registry.
    - Azure SQL Server and the Azure SQL Database for the sample.
    - Storage Account.
* [Build image, push & deploy](.github/workflows/build-deploy.yaml): this workflow will build the sample app using a container, push the container to the Azure Container Registry, deploy the container to the Web App staging slot, update the database and, finally, swap the slots.

To start, you can directly fork this repo and follow the instructions to properly setup the workflows.

### Prerequisites
The [Create Azure Resources](.github/workflows/azuredeploy.yaml) workflow, describes in the `azuredeploy.yaml` file the pre-requisites needed to setup the CI/CD.

### 1. Create the Azure Resource group
Open the Azure Cloud Shell at https://shell.azure.com. You can alternately use the Azure CLI if you've installed it locally. (For more information on Cloud Shell, see the [Cloud Shell Overview](https://docs.microsoft.com/en-us/azure/cloud-shell/overview))   

```
az group create --name {resource-group-name} --location {resource-group-location}
```
Replace the `{resource-group-name}` and the `{resource-group-location}` for one of your preferences. By default, the resource group name used in the .yaml workflows is `rg-todo-sample`, be sure to replace it if you change the name.

Sample:
```
az group create --name rg-todo-sample --location westeurope
```

### 2.  Create Azure credentials with OIDC (federated security)

You'll need an Active Directory application and service principal that can access resources. These instructions show how to create credentials with Azure CLI. You can also [create credentials in the Azure Portal](https://docs.microsoft.com/azure/developer/github/connect-from-azure?tabs=azure-portal%2Clinux). 

If you do not have an existing application, create the Active Directory application. This command will output JSON with an appId that is your client-id.

```
az ad app create --display-name myApp
```

Save the value to use as the AZURE_CLIENT_ID GitHub secret later. You'll use the objectId value when creating federated credentials with Graph API and reference it as the APPLICATION-OBJECT-ID.

Create a service principal. Replace the appID with the appId from your JSON output. This command generates JSON output with a different objectId and will be used in the next step. The new objectId is the assignee-object-id.

```
 az ad sp create --id <appId>
```

Create a new role assignment by subscription and object. By default, the role assignment will be tied to your default subscription. Replace <subscriptionId> with your subscription ID, <resourceGroupName> with your resource group name, and <assigneeObjectId> with the generated assignee-object-id. Learn how to manage Azure subscriptions with the Azure CLI.

az role assignment create --role contributor --subscription <subscriptionId> --assignee-object-id  <assigneeObjectId> --scopes /subscriptions/$subscriptionId/resourceGroups/<resourceGroupName>/providers/Microsoft.Web/sites/--assignee-principal-type ServicePrincipal

Run the following command to create a new federated identity credential for your active directory application.

```
az rest --method POST --uri 'https://graph.microsoft.com/beta/applications/<APPLICATION-OBJECT-ID>/federatedIdentityCredentials' --body '{"name":"<CREDENTIAL-NAME>","issuer":"https://token.actions.githubusercontent.com","subject":"repo:organization/repository:ref:refs/heads/main","description":"Testing","audiences":["api://AzureADTokenExchange"]}' 
```

* Replace APPLICATION-OBJECT-ID with the objectId (generated while creating app) for your Active Directory application.
* Set a value for CREDENTIAL-NAME to reference later.
* Set the subject. The value of this is defined by GitHub depending on your workflow:
    * For Jobs not tied to an environment, include the ref path for branch/tag based on the ref path used for triggering the workflow: repo:< Organization/Repository >:ref:< ref path>. For example, repo:n-username/ node_express:ref:refs/heads/my-branch or repo:n-username/ node_express:ref:refs/tags/my-tag.
    * For workflows triggered by a pull request event: repo:< Organization/Repository >:pull_request.

You'll need to create GitHub secrets for these values from your Azure Active Directory application:
    - AZURE_CLIENT_ID
    - AZURE_TENANT_ID

For more information, see [Connect GitHub and Azure](https://docs.microsoft.com/azure/developer/github/connect-from-azure).

### 2. (Alternate approach) Create a service principal to manage your resource group from GitHub Actions

We will use a service principal from the GitHub workflow to create and manage the azure resources.

```
az ad sp create-for-rbac --name "{service-principal-name}" --sdk-auth --role contributor --scopes /subscriptions/{subscription-id}/resourceGroups/{resource-group-name}
```

The `{service-principal-name}` is the name you want to provide. You can find `{subscription-id}` in the Azure Portal where you have created the resource group. Finally, the `{resource-group-name}` is the name provided in the previous command.

Sample:
```
az ad sp create-for-rbac --name "sp-todo-app" --sdk-auth --role contributor --scopes /subscriptions/00000000-0000-aaaa-bbbb-00000000/resourceGroups/rg-todo-sample
```

Save the command output, it will be used to setup the required `AZURE_CREDENTIALS` secret in the following step.
```
{
  "clientId": "<guid>",
  "clientSecret": "<secret>",
  "subscriptionId": "00000000-0000-aaaa-bbbb-00000000",
  "tenantId": ""00000000-0000-cccc-dddd-00000000"",
  "activeDirectoryEndpointUrl": "https://login.microsoftonline.com",
  "resourceManagerEndpointUrl": "https://management.azure.com/",
  "activeDirectoryGraphResourceId": "https://graph.windows.net/",
  "sqlManagementEndpointUrl": "https://management.core.windows.net:8443/",
  "galleryEndpointUrl": "https://gallery.azure.com/",
  "managementEndpointUrl": "https://management.core.windows.net/"
}

```
For further details, check https://github.com/Azure/login#configure-deployment-credentials

### 3. Configure the required repo secrets 

If you used OIDC for authentication, add the following secrets to your repo:
    - AZURE_CLIENT_ID:  Application (client) ID
    - AZURE_TENANT_ID: Directory (tenant) ID
    - AZURE_SUBSCRIPTION_ID: Subscription ID
    - SQL_SERVER_ADMIN_PASSWORD: password used to setup and access the Azure SQL database.


If you used a service principal for authentication, add the following secrets to your repo:
- AZURE_CREDENTIALS: the content is the output of the previous executed command.
- SQL_SERVER_ADMIN_PASSWORD: this will be the password used to setup and access the Azure SQL database.

There are other additional secrets that you will need to add after the environment has been created in the next step.

For further details, check https://docs.github.com/en/free-pro-team@latest/actions/reference/encrypted-secrets#creating-encrypted-secrets-for-a-repository

Finally, review both workflows and ensure the defined variables have the correct values and matches the pre-requisites you have just setup.


### 4. Execute the Create Resources workflow
 Go to your repo [Actions](../../actions) tab, under *All workflows* you will see the [Create Azure Resources](../../actions?query=workflow%3A"Create+Azure+Resources") workflow. 

Launch the workflow by using the *[workflow_dispatch](https://github.blog/changelog/2020-07-06-github-actions-manual-triggers-with-workflow_dispatch/)* event trigger.

This will create all the required resources in the Azure Subscription and Resource Group you configured.

Now add the following secrets to your repo (those will be used by the build_deploy workflow):
- ACR_USERNAME: you can pick it from the Azure Container Registry settings, in the *Access Keys*.
- ACR_PASSWORD: use one of the passwords from the Azure Container Registry settings, in the *Access Keys*.
- SQL_CONNECTION_STRING: pick it from the SQL DB connection string settings. It has the following format: *Server=tcp:<SQL_SERVER_NAME>.database.windows.net,1433;Initial Catalog=sqldb-todo;Persist Security Info=False;User ID=<SQL_SERVER_ADMIN_LOGIN>;Password=<SQL_SERVER_ADMIN_PASSWORD>;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;*

## Test your CI/CD workflow
To launch the CI/CD workflow (Build image, push & deploy), you just need to make a change in the app code. You will see a new GitHub action initiated in the [Actions](../../actions) tab.

## Workflows YAML explained
As mentioned before, there are two workflows defined in the repo [Actions](../../actions) tab: the *Create Azure Resources* and the *Buid image, push, deploy*.
### Create Azure Resources
Use this workflow to initially setup the Azure Resources by executing the ARM template which contains the resources definition. This workflow is defined in the [azuredeploy.yaml](.github/workflows/azuredeploy.yaml) file, and have the following steps:

* Check out the source code by using the [Checkout](https://github.com/actions/checkout) action.
* Login to azure CLI to gather environment and azure resources information by using the [Azure Login](https://github.com/Azure/login) action.
* Executes a custom in-line script to get the target Azure Subscription Id
* Deploy the resources defined in the provided [ARM template](/infrastructure/azuredeploy.json) by using the [ARM Deploy](https://github.com/Azure/arm-deploy) action.

### Buid image, push, deploy
This workflow builds the container with the latest web app changes, push it to the Azure Container Registry and, updates the web application *staging* slot to point to the latest container pushed. Then updates the database (just in case there is any change to be reflected in the database schema). Finally, swap the slots to leave the latest version in the production slot. 

The workflow is configured to be triggered by each change made to your repo source code (excluding changes affecting to the *infrastructure* and *.github/workflows* folders). 

To ilustrate the versioning, the workflow generates a version number, based in the [github workflow run number](https://docs.github.com/en/free-pro-team@latest/actions/reference/context-and-expression-syntax-for-github-actions#github-context) context variable, which is stored in the app service web application settings. 

To ilustrate the usage of [Environments](https://docs.github.com/en/actions/reference/environments) a *test* environment has been added to the repo and the *Required reviewers* protection rule has been configured to enable the approval or rejection of a certain deployment. For more information check [Reviewing deployments](https://docs.github.com/en/actions/managing-workflow-runs/reviewing-deployments).

The definition is in the [build-deploy.yaml](.github/workflows/build-deploy.yaml) file, and have two jobs with the following steps:
* Job: build
  * Check out the source code by using the [Checkout](https://github.com/actions/checkout) action.
  * Login to azure CLI to gather environment and azure resources information by using the [Azure Login](https://github.com/Azure/login) action.
  * Executes a custom script to build the web application container image and push it to the Azure Container Registry, giving a unique label.
* Job: Deploy (using the environment *test* for explicit approval)
  * Check out the source code by using the [Checkout](https://github.com/actions/checkout) action.
  * Login to azure CLI to gather environment and azure resources information by using the [Azure Login](https://github.com/Azure/login) action.
  * Updates the Web App Settings with the latest values by using the [Azure App Service Settings](https://github.com/Azure/appservice-settings) action.
  * Updates the App Service Web Application deployment for the *staging* slot by using the [Azure Web App Deploy](https://github.com/Azure/webapps-deploy) action.
  * Setup the .NET Core enviroment versio to the latest 3.1, by using the [Setup DotNet](https://github.com/actions/setup-dotnet) action.
  * Executes a custom script to update the SQL Database by using the dotnet entity framework tool.
  * Finally, executes an Azure CLI script to swap the *staging* slot to *production*

## Contributing
Refer to the [Contributing page](/CONTRIBUTING.md)