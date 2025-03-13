# What is this?

Per a request this code deploys an automation account and runbook to do the following:  
- Every 15 minutes check a specific host pool's VMs and if there are no current user sessions, remove the VM and re-add using a Template Spec

Scenario:  
Multisession (1 User Only) or Personal Host Pool in which data is sensitive and VM needs rebuild after use.

PreReqs: A template spec to be created to leveraged for the host OS to be deployed. A Log Analytic Workspace
After the Deployment is complete the following rights need to be added for the automation account:

Subscription: Reader
Contributor for hte resource group hosting the host pool and session hosts.
Log Analaytic Workspace Reader
Secret Uers on the key vault and if utilized an access policy created for the user.

the Default name of the Automation account will start with AA-AVD unless changed in deployment.

Deployment:  

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#blade/Microsoft_Azure_CreateUIDef/CustomDeploymentBlade/uri/https%3A%2F%2Fraw.githubusercontent.com%2FS-Rimmer%2FRebuildAfterLogoff%2Fmaster%2Fdeploy.json/uiFormDefinitionUri/https%3A%2F%2Fraw.githubusercontent.com%2FS-Rimmer%2FRebuildAfterLogoff%2Fmaster%2FuiDefinition.json)

