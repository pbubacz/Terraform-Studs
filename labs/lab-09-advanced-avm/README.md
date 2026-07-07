# Lab 09 — Advanced AVM & Policy (Optional / Stretch)

- **Duration:** 45 min · **Difficulty:** ⭐⭐⭐ · **Depends on:** Lab 08
- **Status:** OPTIONAL — run only if time allows, or assign as follow-up.

## Scenario
Harden a workload and add a **policy-as-code** gate (OPA/Conftest) that runs
against the Terraform plan in JSON form. Optionally, write a `terraform test`.

> Note on AVM: the storage AVM module has migrated to an AzAPI-based interface
> whose plan emits `azapi_resource` (not `azurerm_storage_account`), so a simple
> resource-type policy would not match it. To keep the policy demo concrete and
> readable, this lab hardens a plain `azurerm_storage_account`. The *concept* —
> overriding defaults to enforce a stricter posture — is identical to overriding
> AVM module inputs (discussed in Module 11).

## Tasks

### Part A — Apply a hardened, stricter-than-default posture
In `solution/main.tf`, the storage account disables shared-key auth, blocks
public network/blob access, and enforces TLS 1.2. Run `plan` and confirm.

### Part B — Policy as code with Conftest (OPA)
1. Generate a machine-readable plan:
   ```bash
   terraform plan -out=tfplan
   terraform show -json tfplan > tfplan.json
   ```
2. Evaluate the plan against the Rego policy:
   ```bash
   conftest test tfplan.json --policy ../policy
   ```
3. The policy in `policy/storage.rego` **fails** any storage account that allows
   public blob access — a preventive control in your pipeline.

### Part C — (optional) terraform test
Add a `tests/` file using `terraform test` to assert the module outputs.

## Expected deliverables
- A hardened `azurerm_storage_account` plus a passing policy gate.
- A passing `conftest` run; demonstrate it failing on an insecure change.

## Discussion
- Preventive (policy-as-code/Azure Policy) vs. detective (drift) controls.
- Where in the Lab 6 pipeline does the Conftest step belong? (Before `apply`.)

## Cleanup
```bash
terraform destroy
```
