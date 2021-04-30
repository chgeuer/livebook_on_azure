param prefix string = 'chgeuer2'

@secure()
@minLength(12)
param livebookPassword string = 'Secret123gyJFgny8'

var containerConfig = {
  image: 'livebook/livebook'
  shareNames: {
    mixcache: 'mixcache'
    data: 'data'
  }
  mountPoints: {
    mixcache: '/mixcache'
    data: '/data'
  }
  livebookPort: 80
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2020-08-01-preview' = {
  name: '${prefix}${uniqueString(resourceGroup().name)}'
  location: resourceGroup().location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}

resource shareMixCache 'Microsoft.Storage/storageAccounts/fileServices/shares@2021-02-01' = {
  name: '${storageAccount.name}/default/${containerConfig.shareNames.mixcache}'
}

resource shareData 'Microsoft.Storage/storageAccounts/fileServices/shares@2021-02-01' = {
  name: '${storageAccount.name}/default/${containerConfig.shareNames.data}'
}

resource containerGroup 'Microsoft.ContainerInstance/containerGroups@2019-12-01' = {
  name: '${prefix}-group'
  location: resourceGroup().location
  dependsOn: [
    shareMixCache
    shareData
  ]
  properties: {
    osType: 'Linux'
    restartPolicy: 'OnFailure'
    containers: [
      {
        name: 'livebook'
        properties: {
          image: containerConfig.image
          environmentVariables: [
            {
              name: 'LIVEBOOK_PASSWORD'
              value: livebookPassword
            }
            {
              name: 'LIVEBOOK_COOKIE'
              value: uniqueString('${livebookPassword}${resourceGroup().id}')
            }
            {
              name: 'LIVEBOOK_IP'
              value: '0.0.0.0'
            }
            {
              name: 'LIVEBOOK_PORT'
              value: '${containerConfig.livebookPort}'
            }
            {
              name: 'MIX_INSTALL_DIR'
              value: containerConfig.mountPoints.mixcache
            }
            {
              name: 'LIVEBOOK_ROOT_PATH'
              value: containerConfig.mountPoints.data
            }
          ]
          resources: {
            requests: {
              cpu: 2
              memoryInGB: 1
              gpu:{
                count: 1
                sku: 'V100'
              }
            }
          }
          ports: [
            {
              protocol: 'TCP'
              port: containerConfig.livebookPort
            }
          ]
          volumeMounts: [
            {
              name: 'mixcache'
              mountPath: containerConfig.mountPoints.mixcache
              readOnly: false
            } 
            {
              name: 'data'
              mountPath: containerConfig.mountPoints.data
              readOnly: false
            }
          ]
        }
      }
    ]
    ipAddress: {
      type: 'Public'
      ports: [
        {
          protocol: 'TCP'
          port: containerConfig.livebookPort
        }
      ]
    }
    volumes: [
      {
        name: 'mixcache'
        azureFile: {
          readOnly: false
          shareName: containerConfig.shareNames.mixcache
          storageAccountName: storageAccount.name
          storageAccountKey: listKeys(storageAccount.name, storageAccount.apiVersion).keys[0].value
        }
      }
      {
        name: 'data'
        azureFile: {
          readOnly: false
          shareName: containerConfig.shareNames.data
          storageAccountName: storageAccount.name
          storageAccountKey: listKeys(storageAccount.name, storageAccount.apiVersion).keys[0].value
        }
      }
    ]
  }
}

output containerIpv4Address string = containerGroup.properties.ipAddress.ip
