# Tests

Run the local regressions with `avm test unit`. The mocked apply runs cover the six-field
resource projection, adopted GUID retention, legacy lock notes, immutable edit rejection and
condition add/remove/null/empty request shapes using `Azure/avm-utl-interfaces/azure` 0.7.0.
Plan-only characterizations use the installed AzAPI provider with dummy credentials, disabled
refresh/preflight/provider registration and unreachable loopback endpoints. All data reads and
the primary resource are overridden. Those runs cannot contact Azure and never apply with the
real provider.

After initialization, run `.\tests\unit\Assert-LockGraph.ps1` to check that full destroy removes
the module lock before deleting role assignments. It checks Terraform's actual dependency graph,
not a source-text match. It does not simulate Azure lock propagation or inherited locks.

These tests do not prove AzureRM-to-AzAPI state conversion or successful Azure condition removal.
The recorded upgrade runs at `6591401` and `356eec4` exercised unchanged migration from module
0.3.0 with a CanNotDelete lock and a Reader assignment, including GUID retention and a no-change
second plan. They did not edit the principal or role, or add and then remove a condition. The
default example also lacked those lock/RBAC transitions, and no unit tests were checked in at
`ed1f464`. That is why unchanged migration success did not detect these day-two failures.

Before publishing this repair, separately authorize and run real-Azure upgrade and day-two tests.
Verify unchanged migration and replan, condition addition and removal with ARM readback, and the
documented unlock/delete/recreate/relock sequence. Do not infer those results from mocks or local
provider plans. Location relocation remains an intentional unsupported transition; it was not
fixed by these tests.
