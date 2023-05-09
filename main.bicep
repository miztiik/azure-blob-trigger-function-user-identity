targetScope = 'subscription'

// Parameters
param deploymentParams object
param storageAccountParams object
param logAnalyticsWorkspaceParams object
param funcParams object
param cosmosDbParams object

param brandTags object


var location = deploymentParams.location
var rgName = '${deploymentParams.enterprise_name}_${deploymentParams.enterprise_name_suffix}_${deploymentParams.global_uniqueness}'

param dateNow string = utcNow('yyyy-MM-dd-hh-mm')

param tags object = union(brandTags, {last_deployed:dateNow})

// Create Resource Group
module r_rg 'modules/resource_group/create_rg.bicep' = {
  name: rgName
  params: {
    rgName: rgName
    location: location
    tags:tags
  }
}


// Create the Log Analytics Workspace
module r_logAnalyticsWorkspace 'modules/monitor/log_analytics_workspace.bicep' = {
  scope: resourceGroup(r_rg.name)
  name: '${logAnalyticsWorkspaceParams.workspaceName}_${deploymentParams.global_uniqueness}_La'
  params: {
    deploymentParams:deploymentParams
    logAnalyticsWorkspaceParams: logAnalyticsWorkspaceParams
    tags: tags
  }
}


// Create Storage Account
module r_sa 'modules/storage/create_storage_account.bicep' = {
  scope: resourceGroup(r_rg.name)
  name: '${storageAccountParams.storageAccountNamePrefix}_${deploymentParams.global_uniqueness}_Sa'
  params: {
    deploymentParams:deploymentParams
    storageAccountParams:storageAccountParams
    funcParams: funcParams
    tags: tags
  }
}


// Create Storage Account - Blob container
module r_blob 'modules/storage/create_blob.bicep' = {
  scope: resourceGroup(r_rg.name)
  name: '${storageAccountParams.storageAccountNamePrefix}_${deploymentParams.global_uniqueness}_Blob'
  params: {
    deploymentParams:deploymentParams
    storageAccountParams:storageAccountParams
    storageAccountName: r_sa.outputs.saName
    storageAccountName_1: r_sa.outputs.saName_1
    logAnalyticsWorkspaceId: r_logAnalyticsWorkspace.outputs.logAnalyticsPayGWorkspaceId
    enableDiagnostics: false
  }
  dependsOn: [
    r_sa
  ]
}

// Create Cosmos DB
module r_cosmodb 'modules/database/cosmos.bicep' ={
  scope: resourceGroup(r_rg.name)
  name: '${cosmosDbParams.cosmosDbNamePrefix}_${deploymentParams.global_uniqueness}_cosmosdb'
  params: {
    deploymentParams:deploymentParams
    cosmosDbParams:cosmosDbParams
    tags: tags
  }
}

// Create the function app & Functions
module r_functionApp 'modules/functions/create_function.bicep' = {
  scope: resourceGroup(r_rg.name)
  name: '${funcParams.funcNamePrefix}_${deploymentParams.global_uniqueness}_FnApp'
  params: {
    deploymentParams:deploymentParams
    funcParams: funcParams
    funcSaName: r_sa.outputs.saName_1
    saName: r_sa.outputs.saName
    blobContainerName: r_blob.outputs.blobContainerName
    cosmosDbAccountName: r_cosmodb.outputs.cosmosDbAccountName
    cosmosDbName: r_cosmodb.outputs.cosmosDbName
    cosmosDbContainerName: r_cosmodb.outputs.cosmosDbContainerName
    // appConfigName: r_appConfig.outputs.appConfigName
    logAnalyticsWorkspaceId: r_logAnalyticsWorkspace.outputs.logAnalyticsPayGWorkspaceId
    enableDiagnostics: true
    tags: tags
  }
  dependsOn: [
    r_sa
  ]
}

// Create Event Grid System Topic & Subscription
module r_evntGridSystemTopic 'modules/functions/create_event_grid_topic.bicep' = {
  scope: resourceGroup(r_rg.name)
  name: '${funcParams.funcNamePrefix}_${deploymentParams.global_uniqueness}_event_grid_system_topic'
  params: {
    deploymentParams:deploymentParams
    tags: tags
    saName: r_sa.outputs.saName
    blobContainerName: r_blob.outputs.blobContainerName
    funcParams: funcParams
    funcAppName: r_functionApp.outputs.fnAppName
  }
  dependsOn: [
    r_functionApp
  ]
}
