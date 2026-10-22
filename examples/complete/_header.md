# Complete example

Deploys a DDoS protection plan with tags, a `CanNotDelete` lock, a Reader assignment for the deployment principal, an associated virtual network, and a directly associated Standard public IP.
All direct Azure operations use AzAPI.
The public IP is zone-redundant static IPv4 with regional Standard SKU. Its `ddosSettings` explicitly enables protection and references the plan ID; it does not inherit protection from the VNet.
The network resources default to `westus2` instead of `westus` because the public IP explicitly uses availability zones 1, 2, and 3. Region overrides must also support these zones.
The example checks that Azure returns the expected public-IP protection mode and plan ID, and exposes the association through discrete outputs.
The caller needs permission to create role assignments and locks as well as networking resources.
Applying this example incurs Azure DDoS protection plan and public IP charges. Destroy it when testing is finished.
