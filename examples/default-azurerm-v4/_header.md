# Complete AzAPI example

Deploys a DDoS protection plan with tags, a `CanNotDelete` lock, a Reader assignment for the deployment principal, and an associated virtual network.
The legacy directory name is retained for existing links; all direct Azure operations use AzAPI.
The caller needs permission to create role assignments and locks as well as networking resources.
Applying this example incurs Azure DDoS protection plan charges. Destroy it when testing is finished.
