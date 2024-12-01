# use existing resouce group
data "azurerm_resource_group" "rg" {
  name = "arc-rg"

}

# use the azure container resgistry
data "azurerm_container_registry" "acr" {
  name                = "myacrghadachihi"
  resource_group_name = "arc-rg"
}
# create vnet for the app containers
resource "azurerm_virtual_network" "mycontainer-vnet" {
  name                = "mycontainers-vnet"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}
# create subnet for app containers
resource "azurerm_subnet" "subnet" {
  name                 = var.subnet_name
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.mycontainer-vnet.name
  address_prefixes     = ["10.0.0.0/23"]
  # this bloc is to create delegation for the app env to this subnet
  #   delegation {
  #     name = "containerapp-delegation"
  #     service_delegation {
  #       name = "Microsoft.App/environments"
  #       actions = [
  #         "Microsoft.Network/virtualNetworks/subnets/join/action",
  #       ]
  #     }
  #   }
}

# create log analytics workspace to retrieve the log data in container app
resource "azurerm_log_analytics_workspace" "log_analytics-containers" {
  name                = "myworkspace-123"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
}
# create container app environment 
resource "azurerm_container_app_environment" "myenv" {
  name                       = "myContainerAppEnv"
  location                   = data.azurerm_resource_group.rg.location
  resource_group_name        = data.azurerm_resource_group.rg.name
  infrastructure_subnet_id   = azurerm_subnet.subnet.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.log_analytics-containers.id

}


resource "azurerm_user_assigned_identity" "containerapp" {
  location            = data.azurerm_resource_group.rg.location
  name                = "containerappmi"
  resource_group_name = data.azurerm_resource_group.rg.name
  }

resource "azurerm_role_assignment" "containerapp" {
  scope                = data.azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.containerapp.principal_id
  depends_on = [
    azurerm_user_assigned_identity.containerapp
  ]
}

# Define the backend app
resource "azurerm_container_app" "backend_app" {
  name = "backend-app"

  resource_group_name          = data.azurerm_resource_group.rg.name
  container_app_environment_id = azurerm_container_app_environment.myenv.id
  revision_mode                = "Single"
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.containerapp.id]
  }

  registry {
    server   = data.azurerm_container_registry.acr.login_server
    identity = azurerm_user_assigned_identity.containerapp.id
  }

  template {
    container {
      name  = "backend-container"
      image = "myacrghadachihi.azurecr.io/my_project-backend:latest"

      cpu    = 0.5
      memory = "1.0Gi"
    }
  }
}

# Define the frontend app, referencing the backend app's FQDN
resource "azurerm_container_app" "frontend_app" {
  name = "frontend-app"

  resource_group_name          = data.azurerm_resource_group.rg.name
  container_app_environment_id = azurerm_container_app_environment.myenv.id
  revision_mode                = "Single"
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.containerapp.id]
  }

  registry {
    server   = data.azurerm_container_registry.acr.login_server
    identity = azurerm_user_assigned_identity.containerapp.id
  }

  template {
    container {
      name   = "frontend-container"
      image  = "myacrghadachihi.azurecr.io/my_project-frontend:latest"
      cpu    = 0.5
      memory = "1.0Gi"

      #   env {
      #     name  = "BACKEND_URL"
      #     value = azurerm_container_app.backend_app.latest_revision_fqdn # Dependency on backend app
      #   }
    }
  }
}




