# Lab 07 — AVM Storage Account in the Azure DevOps Pipeline

- **Duration:** 45 min · **Difficulty:** ⭐⭐ · **Depends on:** Lab 06

## Scenario
In Lab 06 you deployed a **hand-written** `azurerm_storage_account` through the
Azure DevOps pipeline (OIDC + PR → plan → gated apply). Now add a **second**
storage account built from the **Azure Verified Module** (AVM)
`Azure/avm-res-storage-storageaccount/azurerm`, ship it through the **same
pipeline**, and compare the two — both in the **HCL definition** and in the
**Azure environment** (the AVM ships Azure Policy / WAF-aligned secure defaults
for free).

> The storage AVM module is **AzAPI-based** (`azapi` provider) and requires
> **Terraform ≥ 1.10**. That's a realistic step up from the azurerm-only labs.

## Prerequisites
- A working **Lab 06** dedicated repo + pipeline (service connection `azure-oidc`,
  backend storage, `production` environment, branch policy).
- The identity behind `azure-oidc` has **Contributor** on the subscription and
  **Storage Blob Data Contributor** on the state storage (from Lab 06).

## Part 1 — Edit your existing Lab 06 code (don't replace it)
Work in your **Lab 06 repo**, on a branch. You'll make **three small edits** —
nothing is copied over wholesale, so you can see exactly what the AVM adds.

### 1a. `versions.tf` — add the AzAPI provider and bump Terraform
The AVM storage module is AzAPI-based. In your existing `versions.tf`:
- raise `required_version` to `>= 1.10`,
- **add** the `azapi` provider to `required_providers`,
- **add** an `azapi` provider block.

```hcl
terraform {
  required_version = ">= 1.15.5"          # was >= 1.7
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azapi = {                            # + ADD
      source  = "Azure/azapi"
      version = "~> 2.8"
    }
  }
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

provider "azapi" {}                       # + ADD
```
> AzAPI authenticates with the **same** `ARM_*` / OIDC env vars the pipeline
> already exports — no extra config needed.

### 1b. `main.tf` — keep the Lab 06 storage account, **add** the AVM module
Leave your existing `azurerm_resource_group.this` and
`azurerm_storage_account.demo` (from Lab 06) **exactly as they are** — that's your
DIY baseline. Append the AVM module and a couple of outputs:

```hcl
locals {
  sa_suffix = "${replace(var.prefix, "-", "")}07" # e.g. tfcourseab07
}

# NEW: AVM storage account (AzAPI-based, secure by default)
module "storage" {
  source  = "Azure/avm-res-storage-storageaccount/azurerm"
  version = "0.7.3"

  name      = "stavm${local.sa_suffix}"
  location  = azurerm_resource_group.this.location
  parent_id = azurerm_resource_group.this.id   # note: resource group ID, not name

  account_sku_name = "Standard_LRS"
  tags             = { course = "terraform-azure", lab = "07" }
  enable_telemetry = true
}

output "avm_storage_name" {
  value = module.storage.name
}
```
> Notice the AVM module takes **`parent_id`** (the RG resource ID) and **no**
> secure flags — the safe defaults are built in. Compare that with the ~8 lines
> of explicit settings on your Lab 06 `demo` account.

### 1c. Pipeline — bump the Terraform version
The module needs Terraform ≥ 1.10. In `azure-pipelines-cli.yml` (or
`azure-pipelines.yml`), change one line:
```yaml
variables:
  terraformVersion: '1.15.7'   # was 1.9.5 — AVM storage needs >= 1.10
```

### 1d. Commit on a branch and open a PR
Direct pushes to `main` are blocked (Lab 06 Part 3), so use a branch:
```powershell
git switch -c avm-storage
git add versions.tf main.tf azure-pipelines-cli.yml
git commit -m "Add AVM storage account alongside the Lab 06 one"
git push -u origin avm-storage
```

> The `solution/` folder shows the **finished** state of these edits for
> reference — read it only after trying the edits yourself.

## Part 2 — Review the plan, then apply
1. The PR triggers **Validate → Plan**. Open the **Plan** stage log — note the
   AVM module expands into **many** `azapi_resource` objects (the account plus
   its secure sub-settings) from just a few input lines, while your `demo`
   account is a single resource.
2. Merge the PR. On `main`, **Apply** waits on the `production` environment —
   **approve** it. `terraform apply` creates the new AVM account next to the
   existing Lab 06 one.

## Part 3 — Compare the definition (HCL)
| Aspect | DIY — Lab 06 `azurerm_storage_account.demo` | AVM — `module "storage"` |
|--------|----------------------------------------------|--------------------------|
| Lines you write | ~8 (and you must remember each secure flag) | ~6 inputs |
| Secure defaults | you set them by hand | on by default |
| Provider | `azurerm` | `azapi` (Entra-ID only, no shared key) |
| Diagnostics / PE / CMK | you wire them up | first-class inputs |
| Testing / upgrades | yours | Microsoft-tested; bump `version` |

## Part 4 — Compare in Azure (secure defaults for free)
Inspect both accounts and see what the AVM enforced **without you asking**. Use
your real names (the Lab 06 account and the new `stavm…` one):

```powershell
$rg      = "rg-tfcourse-ab-lab06"
$diyName = "sttfcourseablab06"     # your Lab 06 account
$avmName = "stavmtfcourseab07"     # the new AVM account (from output avm_storage_name)

# Keep the JMESPath query on ONE line — on Windows `az` is a .cmd wrapper and
# splits multi-line arguments (you'd get: invalid jmespath_type value: '{').
$query = "{publicNetworkAccess:publicNetworkAccess,allowSharedKeyAccess:allowSharedKeyAccess,allowBlobPublicAccess:allowBlobPublicAccess,minimumTlsVersion:minimumTlsVersion,networkDefaultAction:networkRuleSet.defaultAction,crossTenantReplication:allowCrossTenantReplication}"

foreach ($sa in @($diyName, $avmName)) {
  Write-Host "== $sa =="
  az storage account show -n $sa -g $rg --query $query -o jsonc
}
```

The **AVM** account reports `publicNetworkAccess = Disabled`,
`allowSharedKeyAccess = false`, `allowBlobPublicAccess = false`,
`minimumTlsVersion = TLS1_2`, `networkDefaultAction = Deny` — all **by default**.
Your **Lab 06** account only has what you set (e.g. public network access is
still **Enabled** and the network default action is **Allow**). These map
directly to common **Azure Policy** initiatives, e.g.:
- *Storage accounts should disable public network access*
- *Storage accounts should restrict network access*
- *Storage accounts should have shared key access disabled*
- *Secure transfer to storage accounts should be enabled*

So the AVM account is **compliant out of the box**, while the DIY account is only
as compliant as the flags you remembered to set.

## Expected deliverables
- The new AVM storage account (`stavm…`) deployed **next to** your Lab 06 account
  via the same pipeline.
- A short written comparison: LOC written, secure defaults, and which Azure
  Policies each account satisfies by default.

## Discussion
- When would you still write your own resource instead of using AVM?
- How does `enable_telemetry` work and how do you opt out?
- Why does the AzAPI-based module never need a storage **shared key**?

## Notes
The `solution/` uses the current AVM **storage** module interface (`parent_id`,
`account_sku_name`, pinned to `0.7.3`). AVM interfaces evolve — reconciling an
example against the live registry page is a realistic, valuable skill.

## Cleanup
Remove the AVM account the same way you added it: open a PR that **deletes the
`module "storage"` block** (and its outputs), let the pipeline `plan`/`apply`
the removal. To tear everything down locally instead:
```powershell
terraform destroy
```
