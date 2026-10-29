# Complete example

Deploys a DDoS protection plan with tags, a `CanNotDelete` lock, a Reader assignment for the deployment principal, and an associated virtual network.
All direct Azure operations use AzAPI.
Network resources default to `westus2`. This scenario does not create a public IP or require subscription feature registration.
The `resource` output takes its VNet association IDs from the caller-owned VNet. The plan's read-only back-reference is only refreshed after VNet creation, so re-exporting that cached list would cause an output-only change on the first follow-up plan.
The caller needs permission to create role assignments and locks as well as networking resources.
For direct public-IP association, see the separate [individual IP protection example](../individual-ip-protection), which is excluded from automated E2E deployment.
Applying this example incurs Azure DDoS protection plan charges. Destroy it when testing is finished.
