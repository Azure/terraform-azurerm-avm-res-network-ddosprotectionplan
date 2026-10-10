# Tests

Run the local regressions with `avm test unit`. The mocked apply runs cover the six-field
resource projection, adopted GUID retention, legacy lock notes, immutable edit rejection and
condition add/remove/null/empty request shapes using `Azure/avm-utl-interfaces/azure` 0.7.0.
The clear assertions require explicit null condition fields with null omission disabled,
and require unset `principalType` to be absent from the body. The earlier empty-string
assertions passed offline but ARM rejected `conditionVersion = ""` in the live lab.
Mocks and provider plan modifiers do not validate ARM's update semantics.
Plan-only characterizations use the installed AzAPI provider with dummy credentials, disabled
refresh/preflight/provider registration and unreachable loopback endpoints. All data reads and
the primary resource are overridden. Those runs cannot contact Azure and never apply with the
real provider.

After initialization, run `.\tests\unit\Assert-LockGraph.ps1` to check that full destroy removes
the module lock before deleting role assignments. It checks Terraform's actual dependency graph,
not a source-text match. It does not simulate Azure lock propagation or inherited locks.

The unit tests do not prove AzureRM-to-AzAPI state conversion or successful Azure condition removal.
The recorded upgrade runs at `6591401` and `356eec4` exercised unchanged migration from module
0.3.0 with a CanNotDelete lock and a Reader assignment, including GUID retention and a no-change
second plan. They did not edit the principal or role, or add and then remove a condition. The
default example also lacked those lock/RBAC transitions, and no unit tests were checked in at
`ed1f464`. That is why unchanged migration success did not detect these day-two failures.

The authorized 2026-10-08 live condition-reset check used AzAPI 2.13.0, interfaces 0.7.0,
the Storage Blob Data Reader role and a CanNotDelete lock in an isolated
`e2e-repair-ddos-fix-` resource group. Initial ARM readback confirmed the condition and version
`2.0`. Clearing planned and applied zero adds, one in-place update and zero destroys.
ARM then returned null for both condition fields, retained the assignment GUID and derived
`principalType = User`, and a refresh-enabled `terraform plan -detailed-exitcode` returned
exit 0 with `No changes`. All five managed resources were destroyed and resource-group
absence was verified with `az group exists`.

Before publishing, separately authorize real-Azure unchanged migration/replan and the
documented unlock/delete/recreate/relock sequence. The condition-reset check does not prove
those scenarios, inherited-lock behavior or other provider versions. Do not infer their
results from mocks or local provider plans. Location relocation remains an intentional
unsupported transition; it was not fixed by these tests.
