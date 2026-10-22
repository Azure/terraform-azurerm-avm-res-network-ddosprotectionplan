# Complete example

Deploys a DDoS protection plan with tags, a `CanNotDelete` lock, a Reader assignment for the deployment principal, an associated virtual network, and a directly associated Standard public IP.
All direct Azure operations use AzAPI.
The public IP is zone-redundant static IPv4 with regional Standard SKU. Its `ddosSettings` explicitly enables protection and references the plan ID; it does not inherit protection from the VNet.
The network resources default to `westus2` instead of `westus` because the public IP explicitly uses availability zones 1, 2, and 3. Region overrides must also support these zones.
The example checks that Azure returns the expected public-IP protection mode and plan ID, and exposes the association through discrete outputs.
The `resource` output takes its VNet association IDs from the caller-owned VNet. The plan's read-only back-reference is only refreshed after VNet creation, so re-exporting that cached list would cause an output-only change on the first follow-up plan.
The caller needs permission to create role assignments and locks as well as networking resources.
Direct public-IP plan association requires the subscription feature `Microsoft.Network/AllowBringYourOwnPublicIpAddress` to be registered and the `Microsoft.Network` resource provider registration to be refreshed afterward. Coordinate this subscription-wide prerequisite with an administrator before running the example; it is not registered by the example or undone by its destruction.
Applying this example incurs Azure DDoS protection plan and public IP charges. Destroy it when testing is finished.
