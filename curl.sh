curl -v -X POST "https://cloud.stage-seqera.io/api/compute-envs?workspaceId=280116106690509" \
  -H "Authorization: Bearer eyJ0aWQiOiAzNTh9LmY5NWEzYTljZDIxNTEwZDJjM2JlNWM5MTNiMWViNTZmNjAxN2NiYWE=" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{
    "computeEnv": {
      "credentialsId": "3YNSNlPLV4BwaWkNO2rmdx",
      "name": "tf-pool",
      "platform": "azure-batch",
      "config": {
        "workDir": "az://scidev-useast",
        "region": "eastus",
        "headPool": "tf-pool",
        "waveEnabled": false,
        "fusion2Enabled": false,
        "deleteJobsOnCompletion": "always",
        "deletePoolsOnCompletion": false,
        "managedIdentityClientId": "6186e1c7-3402-4fba-ba02-4567f2aeeb94"
      }
    }
  }'