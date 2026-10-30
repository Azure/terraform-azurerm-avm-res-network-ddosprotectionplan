# Individual IP protection example

Demonstrates assigning a caller-owned Standard public IP directly to a DDoS protection plan using AzAPI.
The zone-redundant static IPv4 address uses regional Standard SKU, `ddosSettings.protectionMode = "Enabled"`, and the module's plan ID. It does not rely on VNet inheritance.
This is direct association with a DDoS protection plan, not standalone DDoS IP Protection without a plan, and it does not create a bring-your-own IP prefix.

**Manual deployment only:** direct public-IP plan association requires the subscription feature `Microsoft.Network/AllowBringYourOwnPublicIpAddress` and a refreshed `Microsoft.Network` provider registration.
Use an already-enabled subscription with administrator approval. The example does not register features; AVM CI cannot register this prerequisite.
The `.e2eignore` marker excludes this scenario from automated E2E discovery. Mocked tests still cover its request body, controls, outputs and Azure-response postcondition; skipping deployment is not runtime verification.

Resources default to `westus2`; region overrides must support public IP availability zones 1, 2 and 3.
The example checks Azure's returned protection mode and plan ID and exposes them through outputs.
To run manually, authenticate to an approved subscription, enter this directory, and run `terraform init`, `terraform plan`, `terraform apply`, a follow-up `terraform plan`, and `terraform destroy`. Review plans and verify cleanup.
Deployment incurs Azure DDoS protection plan and public IP charges.
