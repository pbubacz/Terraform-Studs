# Lab 06 — CI/CD with OIDC + Shift-Left

- **Duration:** 60 min · **Difficulty:** ⭐⭐⭐ · **Depends on:** Lab 04

## Scenario
Automate Terraform with a secure pipeline: **no long-lived secrets** (OIDC /
workload identity federation), static analysis (tfsec/Checkov), `plan` on pull
requests, and a gated `apply` on merge to `main`. Pick **GitHub Actions** or
**Azure DevOps** — both are provided.

## Part 1 — Create a federated identity (no secrets)

```bash
# 1. App registration
appId=$(az ad app create --display-name "tfcourse-oidc-ab" --query appId -o tsv)
az ad sp create --id "$appId"

# 2. Federated credentials (GitHub example — match YOUR org/repo/branch)
az ad app federated-credential create --id "$appId" --parameters '{
  "name": "github-main",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:<ORG>/<REPO>:ref:refs/heads/main",
  "audiences": ["api://AzureADTokenExchange"]
}'

az ad app federated-credential create --id "$appId" --parameters '{
  "name": "github-pr",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:<ORG>/<REPO>:pull_request",
  "audiences": ["api://AzureADTokenExchange"]
}'

# 3. Grant least-privilege role on the sandbox subscription
subId=$(az account show --query id -o tsv)
tenantId=$(az account show --query tenantId -o tsv)
spId=$(az ad sp show --id "$appId" --query id -o tsv)
az role assignment create --assignee-object-id "$spId" \
  --assignee-principal-type ServicePrincipal \
  --role "Contributor" --scope "/subscriptions/$subId"
```

Store these as **non-secret** repo variables: `AZURE_CLIENT_ID` (=appId),
`AZURE_TENANT_ID` (=tenantId), `AZURE_SUBSCRIPTION_ID` (=subId).

> The steps above are the **GitHub Actions** path. If you use **Azure DevOps**,
> skip the manual `az ad app federated-credential` calls in step 2 — Azure
> DevOps generates the federation subject for you. Follow **Part 1B** instead.

## Part 1B — Azure DevOps setup (Workload identity federation)

> Do this instead of Part 1 step 2 when you target Azure DevOps. You still need
> an app registration + role assignment, but the **service connection** creates
> and manages the federated credential automatically.

### 1. Create the Workload identity federation service connection

The **automatic** flow lets Azure DevOps create the app registration, service
principal, and federated credential in one step:

1. **Project settings → Service connections → New service connection**.
2. Choose **Azure Resource Manager**, then **Workload Identity federation
   (automatic)**.
3. Scope level **Subscription** → pick your sandbox subscription and (optionally)
   a resource group.
4. In the Field **Service Connection Name** name it **`azure-oidc`** (the pipeline references this name via the
   `serviceConnection` variable).
5. Grant pipeline access: enable **Grant access permission to all pipelines**
   for the lab, or authorize the pipeline on first run.
6. Click **Save**. Azure DevOps creates the app registration, service principal, and federated credential for you.

> **Manual flow (bring your own app registration):** choose **Workload Identity
> federation (manual)** instead. Azure DevOps shows an **Issuer** and **Subject
> identifier** — copy both and register them as a federated credential on your
> app:
>
> ```bash
> az ad app federated-credential create --id "$appId" --parameters '{
>   "name": "ado-oidc",
>   "issuer": "<ISSUER-from-ADO>",
>   "subject": "<SUBJECT-from-ADO>",
>   "audiences": ["api://AzureADTokenExchange"]
> }'
> ```
>
> Then grant the same **Contributor** role assignment from Part 1 step 3.

### 2. Confirm the backend storage exists

The pipeline initializes the `azurerm` backend against these resources — create
them once (from Lab 04) if they don't exist, and make sure the service
connection's identity has **Contributor** (or **Storage Blob Data Contributor**)
on them:

| Setting | Value |
| --- | --- |
| Resource group | `rg-tfcourse-ab-tfstate` |
| Storage account | `sttfcourseabtfstate` |
| Container | `tfstate` |
| State key | `lab06.tfstate` |

> ⚠️ **The storage account name must be GLOBALLY UNIQUE across all of Azure.**
> `sttfcourseabtfstate` is almost certainly taken — pick your own (lowercase,
> 3–24 chars, letters/digits only). If you change it, you **must** update
> `backendAzureRmStorageAccountName` in `azuredevops/azure-pipelines.yml` to
> match, otherwise `terraform init` fails.

Create them with the Azure CLI (storage account names are globally unique and
must be lowercase, 3–24 chars):

```powershell
$location  = "polandcentral"
$rg        = "rg-tfcourse-ab-tfstate"
$sa        = "sttfcourseabtfstate"
$container = "tfstate"

# Resource group
az group create --name $rg --location $location

# Storage account (TLS 1.2, no public blob access, key access disabled)
az storage account create `
  --name $sa `
  --resource-group $rg `
  --location $location `
  --sku Standard_LRS `
  --kind StorageV2 `
  --min-tls-version TLS1_2 `
  --allow-blob-public-access false `
  --allow-shared-key-access false

# Blob container (uses your Entra ID identity, not an account key)
az storage container create `
  --name $container `
  --account-name $sa `
  --auth-mode login
```

Because shared-key access is **disabled** (`--allow-shared-key-access false`),
Terraform authenticates to the blob backend with **Entra ID (AAD)** — which
needs a **data-plane** role. The `azure-oidc` identity's subscription
`Contributor` (management plane) is **not** enough. Grant it
**Storage Blob Data Contributor** on the state storage account:

**Find the `AZURE_CLIENT_ID` of the `azure-oidc` service connection** — use any
of these:

- **Portal (Azure DevOps):** *Project settings → Service connections →
  `azure-oidc` → Manage App registration**, then you will be redirected to Azure Entra ID where  
   the **Application (client) ID** is shown on the details page in section "Essentials"
- **Azure CLI (Entra ID):** if you know the app's display name (e.g. it was
  auto-created as `<org>-<project>-<guid>`):
  ```powershell
  az ad app list --display-name "<app-display-name>" --query "[].appId" -o tsv
  ```
- **Azure DevOps CLI:** read it straight from the service connection:
  ```powershell
  az devops service-endpoint list `
    --organization "https://dev.azure.com/<ORG>" `
    --project "<PROJECT>" `
    --query "[?name=='azure-oidc'].authorization.parameters.serviceprincipalid" -o tsv
  ```

Then assign the role:

```powershell
# re-declare these if you're in a new terminal (they must not be empty)
$rg       = "rg-tfcourse-ab-tfstate" # adjust if you changed it
$sa       = "sttfcourseabtfstate" # adjust if you changed it
$clientId = "<AZURE_CLIENT_ID>"   # app/client ID of the azure-oidc service connection

$saId = az storage account show --name $sa --resource-group $rg --query id -o tsv

az role assignment create `
  --assignee $clientId `
  --role "Storage Blob Data Contributor" `
  --scope $saId
```
> RBAC can take 1–2 minutes to propagate. Without this role, `terraform init`
> fails with `403 AuthorizationPermissionMismatch`.

The same identity also needs a **management-plane** role to create the resources
(resource group, storage account, …). The automatic service-connection flow may
not have granted it — assign **Contributor** on the subscription:

```powershell
$clientId = "<AZURE_CLIENT_ID>"   # same app/client ID as above
$subId = az account show --query id -o tsv

az role assignment create `
  --assignee $clientId `
  --role "Contributor" `
  --scope "/subscriptions/$subId"
```
> Without this, `terraform apply` fails with
> `403 AuthorizationFailed … Microsoft.Resources/subscriptions/resourceGroups/read`.
> Scope it to a resource group instead of the whole subscription for tighter
> least-privilege (but creating a **new** RG needs subscription scope).

> These names are hard-coded in `azuredevops/azure-pipelines.yml`. Change them in
> the YAML if your backend uses different names.

## Part 2 — Add the pipeline
- **GitHub:** copy `github/terraform.yml` to `.github/workflows/terraform.yml`.
- **Azure DevOps:** put the Terraform code in a **dedicated Azure Repos Git
  repo** (separate from this course repo), with the code at the **repo root**,
  then create the pipeline from it:
  1. **Repos → Files → + New repository** → create a repo, e.g. `tf-oidc-lab`
     (initialize it empty or with a README).
  2. Copy the contents of this lab's **`starter/`** folder into the **root** of
     that repo, and add `azure-pipelines.yml` (from `azuredevops/`) at the root
     too. The layout should be flat:
     ```text
     tf-oidc-lab/
     ├─ azure-pipelines.yml
     ├─ main.tf          # resource group + storage account (secure baseline)
     ├─ versions.tf      # terraform + azurerm provider, backend "azurerm" {}
     └─ backend.hcl      # backend config (local / GitHub init)
     ```
  3. Because the code now sits at the root, set **`workingDir: '.'`** in
     `azure-pipelines.yml` (already the default in the provided file) and confirm
     `backendAzureRmStorageAccountName`, `serviceConnection: azure-oidc`, and
     `backendAzureRmKey`.
  4. Commit and push:
     ```powershell
     git init
     git add .
     git commit -m "Terraform + pipeline"
     git remote add origin https://dev.azure.com/<ORG>/<PROJECT>/_git/tf-oidc-lab
     git push -u origin main
     ```
  5. **Pipelines → Create pipeline → Azure Repos Git** → select that repo.
  6. **Existing Azure Pipelines YAML file** → path `/azure-pipelines.yml`.
  7. **Save** (not "Save and run") so the branch policy controls PR runs.

> **Marketplace extension required for `azure-pipelines.yml`.** That file uses
> the `TerraformInstaller` / `TerraformTaskV4` tasks, which come from the
> [Terraform extension](https://marketplace.visualstudio.com/items?itemName=ms-devlabs.custom-terraform-tasks)
> (publisher *Microsoft DevLabs*). An **org admin** must install it once
> (**Organization settings → Extensions**), otherwise the run fails with
> *"A task is missing … 'TerraformInstaller' / 'TerraformTaskV4'"*.
>
> **Can't install extensions?** Use **`azuredevops/azure-pipelines-cli.yml`**
> instead — it needs **no extensions** (only the built-in `AzureCLI@2` task plus
> the Terraform CLI pre-installed on the hosted agent). Point the pipeline at
> `/azure-pipelines-cli.yml` in step 6.

> **Why a separate repo?** Keeping the Terraform code at the **repo root** makes
> `workingDir: '.'` and the backend paths simple and portable — exactly how a
> real project is structured (one app/stack per repo). The paths **inside** the
> YAML are resolved **relative to the repo root**, so a flat layout keeps them
> short. Don't point the pipeline at this course repo; use your own dedicated one.

The pipeline runs three stages: **Validate** (`fmt -check` → `init` → `validate`
→ `tfsec`) → **Plan** (`terraform plan -out=tfplan`, published as an artifact) →
**Apply** (only on `main`, environment-gated, applies the **saved** plan). On a
PR the run stops after Plan; on merge to `main` all three run.

### Gate the pipeline (Azure DevOps — do this **after** the pipeline exists)

These two gates reference the pipeline you just created, so configure them now:

**Create the `production` environment + approval gate** — the `Apply` stage
deploys to an environment named **`production`**:

1. **Pipelines → Environments → New environment** named **`production`**
   (resource: **None**).
2. Open it → **⋯ → Approvals and checks → Approvals** → add yourself/your team as
   **required reviewers**. This gates `apply` behind a manual approval.

**Enable PR build validation** (so the plan runs on PRs) — Azure DevOps does not
run PR pipelines automatically from YAML `pr:` triggers for all repo types, so
add a branch policy:

1. **Repos → Branches → `main` → ⋯ → Branch policies**.
2. **Build validation → +** → select this pipeline → trigger **Automatic** →
   optionally **Required**. Now every PR to `main` runs `Validate` + `Plan`.

### First run — deploy and verify in Azure

Before the shift-left demo, run the pipeline once end-to-end so the environment
actually exists in Azure and you've confirmed OIDC + backend + apply all work.

1. Trigger the pipeline on `main` (push the starter, or **Run pipeline**).
2. `Validate` + `Plan` should be green (OIDC auth + `terraform init` succeed).
3. The `Apply` stage pauses on the **`production`** environment — **approve** it.
4. `terraform apply` runs and creates the resources.

**Verify the resources exist:**
```powershell
# resource group + storage account created by the config
az group show --name "rg-tfcourse-ab-lab06" --query name -o tsv
az storage account list `
  --resource-group "rg-tfcourse-ab-lab06" `
  --query "[].name" -o tsv

# confirm remote state was written to the backend
az storage blob list `
  --account-name "sttfcourseabtfstate" `
  --container-name "tfstate" `
  --auth-mode login `
  --query "[?name=='lab06.tfstate'].name" -o tsv
```
> If `Apply` fails on RBAC (`AuthorizationFailed`), the service connection
> identity needs **Contributor** on the subscription (Part 1 step 3) and
> **Storage Blob Data Contributor** on the state storage account.

## Part 3 — Prove the shift-left gate
The goal: prove the pipeline **blocks an insecure change** before it reaches
`main`. You open a PR with a bad setting, watch tfsec fail the required check,
then fix it and see the plan comment appear.

### 0. Make sure there's a resource to scan
The **`starter/`** code already includes a **storage account** with a secure
baseline (`min_tls_version = "TLS1_2"`, `allow_nested_items_to_be_public =
false`) — that's what tfsec will scan. Just confirm your repo `main` has it:

```powershell
# verify the repo actually contains .tf files
Get-ChildItem -Filter *.tf

# confirm the storage account resource is present
Select-String -Path .\main.tf -Pattern 'azurerm_storage_account'
```
> If you customized the storage account `name`, remember it must be **globally
> unique** (lowercase, 3–24 chars).

### 1. Try to change `main` directly (branch protection blocks it)
First prove that **direct pushes to `main` are rejected**. Make the insecure
edit straight on `main` and try to push it. Lower the storage account's TLS
floor to an **insecure** value in `main.tf`:
```hcl
resource "azurerm_storage_account" "demo" {
  # …existing config…
  min_tls_version = "TLS1_0"   # ⚠️ insecure on purpose (tfsec AVD-AZU-0011)
}
```
> Use a setting tfsec **actually flags**. `min_tls_version = "TLS1_0"` and
> `https_traffic_only_enabled = false` are reliably caught. 

```powershell
git checkout main
git add main.tf
git commit -m "Demo: insecure storage setting (direct to main)"
git push origin main
```
The push is **rejected** by the branch policy:
```text
remote: TF402455: Pushes to this branch are not permitted; you must use a pull request to update this branch.
! [remote rejected] main -> main (TF402455: ...)
error: failed to push some refs to 'https://dev.azure.com/...'
```
> This is the branch protection working: even a valid change can't bypass the PR
> + build-validation gate. If the push **succeeds**, your branch policy from
> **Part 2 → Gate the pipeline** isn't active on `main`.

### 2. Move the change to a feature branch and open a PR
Your insecure commit is already local — put it on a branch instead and push that:
```powershell
git switch -c insecure-demo      # branch now carries your commit
git push -u origin insecure-demo
```
Then in **Azure DevOps → Repos → Pull requests → New pull request**: source
`insecure-demo` → target `main`, and **Create**.
> Optional: clean the extra commit off your local `main` with
> `git switch main; git reset --hard origin/main`.

### 3. Watch the shift-left gate block the merge
- The **build validation** policy triggers the pipeline on the PR.
- The `tfsec` step in the **Validate** stage **fails**, so the required check is
  red and the **Complete** (merge) button is blocked.
- Open the failed run → **Validate** job → tfsec output to see the exact rule
  that fired.

### 4. Fix it and confirm the PR becomes mergeable
```powershell
# set min_tls_version back to "TLS1_2"
git commit -am "Fix: restore TLS1_2 on storage account"
git push
```
- The pipeline re-runs automatically on the updated PR.
- tfsec now **passes**, and the **Plan** stage produces a green plan.
- The required check turns green and the PR can be **Completed** (merged).

### 5. See the gated apply
On merge to `main`, the **Apply** stage runs but **waits for approval** on the
`production` environment. Approve it to let `terraform apply` run.

## Expected deliverables
- A green pipeline authenticating to Azure via **OIDC with zero secrets**.
- A PR comment showing the plan output.
- A failing security scan blocking a bad change.

## Common failure
`AADSTS70021` / `no matching federated identity` → the credential **subject**
doesn't match the workflow trigger (`repo:org/repo:ref:refs/heads/main`,
`repo:org/repo:pull_request`, or an environment subject). Align them exactly.

**Azure DevOps specific:**
- *"A task is missing … 'TerraformInstaller' / 'TerraformTaskV4'"* → the Terraform
  Marketplace extension isn't installed in the org. Either install
  [it](https://marketplace.visualstudio.com/items?itemName=ms-devlabs.custom-terraform-tasks)
  (org admin) or switch the pipeline to `azuredevops/azure-pipelines-cli.yml`,
  which needs no extensions.
- *`terraform init` fails with `403 AuthorizationPermissionMismatch`* → the
  service connection identity lacks **Storage Blob Data Contributor** on the
  state storage account (subscription `Contributor` is management-plane only).
  Assign the data-plane role (**Part 1B step 2**) and wait ~1–2 min.
- *`Authenticating using the Azure CLI is only supported as a User (not a Service
  Principal)`* → you're on the CLI pipeline without OIDC env vars. Ensure the
  `AzureCLI@2` steps set `addSpnToEnvironment: true` and export `ARM_USE_OIDC`,
  `ARM_CLIENT_ID`, `ARM_TENANT_ID`, `ARM_OIDC_TOKEN` (already done in
  `azure-pipelines-cli.yml`).
- *"There was a resource authorization issue"* / the pipeline can't use the
  service connection → authorize it (**Part 1B step 1.5**) or grant access to all
  pipelines.
- *Plan stage never runs on a PR* → build validation branch policy is missing
  (**Part 2 → Gate the pipeline**); the YAML `pr:` trigger alone isn't enough for
  Azure Repos.
- *`apply` runs without approval* → the `production` environment has no approval
  check (**Part 2 → Gate the pipeline**).

## Cleanup
Disable/delete the app registration and role assignment when done.
