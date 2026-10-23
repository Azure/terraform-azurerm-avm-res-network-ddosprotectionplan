# Examples

| Example | Scenario |
| --- | --- |
| [default](./default) | A DDoS protection plan with default optional settings and an AzAPI resource group. |
| [complete](./complete) | A DDoS protection plan with tags, a `CanNotDelete` lock, a Reader assignment, an associated virtual network, and a directly associated Standard public IP. |

Both examples use AzAPI for all direct Azure operations and run without required input variables.

## Running the examples

Authenticate to an isolated Azure test subscription, then run from the repository root with PowerShell 7.4 or later:

```powershell
Import-Module Avm.Authoring
avm test e2e --example default
avm test e2e --example complete
```

Each command deploys the selected example, checks idempotency, and destroys the test resources.
The `complete` example requires permission to create role assignments and locks as well as networking resources.
Azure DDoS protection plans incur charges; use an approved test scope and verify cleanup.

## Adding or updating examples

- Use a scenario-based directory name and document it in `_header.md` and `_footer.md`.
- Keep examples deployable and idempotent without required input variables.
- Use the [AVM naming module](https://registry.terraform.io/modules/Azure/avm-utl-naming/azure/latest) for unique resource names.
- Run `avm pre-commit` from the repository root to format Terraform and regenerate example READMEs. Do not edit generated READMEs directly.
- Run `avm test e2e --list` to verify example discovery.
