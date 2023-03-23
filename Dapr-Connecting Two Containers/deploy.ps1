$grp = "ca-session-rg"
$loc = "eastus"
$environment = "ca-session-env"
$STORAGE_ACCOUNT = "bayanstrgacct"

# creating resource group
az group create --name $grp --location $loc 
                

# creating storage account
az storage account create --name $STORAGE_ACCOUNT --resource-group $grp --location $loc --sku Standard_RAGRS  --kind StorageV2
                 
      

$storageKey = (az storage account keys list --account-name $STORAGE_ACCOUNT --resource-group $grp --output json --query "[0].value")
(Get-Content "components\statestore.yml") -Replace '"STORAGE_ACCOUNT_KEY"', $storageKey | Set-Content "components\statestore.yml"
(Get-Content "components\statestore.yml") -Replace 'STORAGE_NAME', $STORAGE_ACCOUNT | Set-Content "components\statestore.yml"

# creating environment
az containerapp env create --name $environment --resource-group $grp --internal-only false --location $loc


# setting dapr state store
az containerapp env dapr-component set --name $environment --resource-group $grp --dapr-component-name statestore --yaml '.\components\statestore.yml'


az containerapp env dapr-component list --resource-group $grp --name $environment --output json

# rebuild images
docker build -t bayanhassan/todoappbackend -f 'TodoApp.Backend\Dockerfile' .
docker push bayanhassan/todoappbackend

docker build -t bayanhassan/todoappfrontend -f 'TodoApp.Frontend\Dockerfile' .
docker push bayanhassan/todoappfrontend

# creating the backend
az containerapp create `
  --name todo-back `
  --resource-group $grp `
  --environment $environment `
  --image bayanhassan/todoappbackend:latest `
  --target-port 80 `
  --ingress 'internal' `
  --min-replicas 1 `
  --max-replicas 5 `
  --enable-dapr `
  --env-vars ASPNETCORE_ENVIRONMENT="Development" `
  --dapr-app-port 80 `
  --dapr-app-id todo-back

# creating the frontend
az containerapp create `
  --name todo-front `
  --resource-group $grp `
  --environment $environment `
  --image bayanhassan/todoappfrontend:latest `
  --target-port 80 `
  --ingress 'external' `
  --min-replicas 0 `
  --max-replicas 5 `
  --enable-dapr `
  --env-vars ASPNETCORE_ENVIRONMENT="Development" `
  --dapr-app-port 80 `
  --dapr-app-id todo-front



