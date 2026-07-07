# Hands-On Labs — Index, Setup, Troubleshooting & Glossary

These labs are **cumulative**: later labs reuse outputs from earlier ones. Work
them in order. Each lab folder has its own `README.md` (the lab guide), a
`starter/` area for your own code, and a `solution/` answer key.

## Lab map

| Lab | Title | Duration | Difficulty | Depends on |
|-----|-------|----------|-----------|------------|
| [00](lab-00-setup/README.md) | Environment verification | 15m | ⭐ | – |
| [01](lab-01-first-resources/README.md) | First Azure resources | 30m | ⭐ | 00 |
| [02](lab-02-expressions/README.md) | Expressions, functions & `for_each` | 30m | ⭐⭐ | 01 |
| [03](lab-03-refactoring/README.md) | Safe refactoring (`import`/`moved`/`removed`) | 30m | ⭐⭐ | 01 |
| [04](lab-04-expressions-functions/README.md) | Expressions, functions & dynamic blocks | 60m | ⭐⭐⭐ | 02 |
| [05](lab-05-modules/README.md) | Author & compose a module | 45m | ⭐⭐ | 02, 04 |
| [06](lab-06-cicd-oidc/README.md) | CI/CD with OIDC + shift-left (GitHub / Azure DevOps) | 60m | ⭐⭐⭐ | 04 |
| [07](lab-07-avm-resource/README.md) | AVM storage account in the pipeline | 45m | ⭐⭐ | 06 |
| [08](lab-08-multi-layer/README.md) | Multi-team, multi-layer architecture with AVM | 90m | ⭐⭐⭐ | 04, 06, 07 |
| [09](lab-09-advanced-avm/README.md) | Advanced AVM & policy as code (optional) | 45m | ⭐⭐⭐ | 08 |

### Day-2 / advanced track (labs 6–9)

Labs 6–9 move from local authoring to **team delivery** on Azure:

- **Lab 06 — CI/CD with OIDC + shift-left.** Automate Terraform with a secretless
  pipeline (workload identity federation), static analysis (tfsec/Checkov),
  `plan` on pull requests, and a gated `apply` on merge. Includes both a
  **GitHub Actions** and an **Azure DevOps** path.
- **Lab 07 — AVM storage account in the pipeline.** Add a second storage account
  built from the **Azure Verified Module** (AzAPI-based, Terraform ≥ 1.10),
  ship it through the same Lab 06 pipeline, and compare hand-written HCL vs. the
  AVM's secure defaults.
- **Lab 08 — Multi-team, multi-layer architecture.** Split platform and workload
  into two state files; the workload consumes platform outputs via
  `terraform_remote_state` for a clean one-way dependency.
- **Lab 09 — Advanced AVM & policy as code (optional).** Harden a workload and
  add an OPA/Conftest policy gate that evaluates the Terraform plan JSON before
  `apply` — a preventive control in the pipeline.

## Environment setup

| Tool | Purpose | Verify |
|------|---------|--------|
| Terraform CLI (>= 1.7) | Core engine | `terraform version` |
| Azure CLI | Auth + subscription | `az login` then `az account show` |
| VS Code + HashiCorp Terraform extension | Authoring | extension installed |
| Git | Version control | `git --version` |
| GitHub or Azure DevOps account | Day-2 pipelines | repo access |
| tfsec **or** Checkov | Static analysis | `tfsec --version` / `checkov --version` |

### One-time configuration

```bash
az login
az account set --subscription "<subscription-id>"
az account show -o table        # confirm the right subscription/tenant
```

Set per-student values (used across labs). On PowerShell:

```powershell
$env:TF_VAR_prefix   = "tfcourse-ab"     # your initials
$env:TF_VAR_location = "polandcentral"
$env:TF_VAR_owner    = "ab@example.com"
```

> The AzureRM provider picks up your `az login` context automatically for local
> labs. OIDC (no secrets) is introduced in **Lab 6** for pipelines.

## Key commands cheat-sheet

```bash
terraform init                 # download providers, configure backend
terraform fmt -recursive       # canonical formatting
terraform validate             # syntax + internal consistency
terraform plan -out=tfplan     # preview changes, save plan
terraform apply tfplan         # apply the saved plan
terraform destroy              # tear everything down
terraform console              # REPL for expressions / state inspection
terraform state list           # list resources in state
terraform state show <addr>    # inspect one resource
```

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| `Error acquiring the state lock` | Concurrent run / stale lease | Wait; only break the lease if you are sure no run is active |
| `AADSTS...` auth error | Wrong tenant/subscription or expired login | `az login`; `az account set` |
| Plan shows unexpected **destroy/replace** | Renamed a resource without a `moved` block | Add a `moved` block |
| `Backend initialization required` | Backend config changed | `terraform init -reconfigure` |
| Backend init fails on storage | Storage/container missing or no RBAC | Run Lab 4 bootstrap; assign `Storage Blob Data Contributor` |
| Provider version keeps changing | Lock file not committed | Commit `.terraform.lock.hcl` |
| OIDC pipeline returns `401`/`AADSTS70021` | Federated credential `subject` mismatch | Align subject to `repo:org/repo:ref:refs/heads/main` or environment |
| `quota exceeded` on apply | Sandbox limits | Use smaller SKUs / fewer instances |

## Glossary

| Term | Meaning |
|------|---------|
| **Provider** | Plugin that maps Terraform resources to an API (e.g., `azurerm`) |
| **Resource** | A managed infrastructure object (`azurerm_resource_group`) |
| **Data source** | Read-only lookup of existing infrastructure |
| **State** | Terraform's record of real-world resources it manages |
| **Backend** | Where state is stored (local, or Azure Blob = remote) |
| **Lock** | Mechanism preventing concurrent state writes (blob lease) |
| **Plan / Apply** | Preview vs. execute changes |
| **Drift** | Difference between real infra and recorded state |
| **Module** | Reusable container of resources with input/output contract |
| **Root module** | The directory where you run `terraform` |
| **`for_each` / `count`** | Meta-arguments to create multiple instances |
| **`depends_on`** | Explicit dependency when no reference exists |
| **`import` / `moved` / `removed`** | Blocks to adopt, rename, or release resources without destroy |
| **Remote state** | State stored centrally (Azure Blob) for team use |
| **OIDC / workload identity** | Secretless federated auth for pipelines |
| **Shift-left** | Catching issues early (validate, scan) before deploy |
| **Policy as code** | Governance rules expressed and enforced as code |
| **AVM** | Azure Verified Modules — Microsoft-owned, tested standard modules |
| **Resource / Pattern / Utility module** | The three AVM module classes |
| **Landing zone** | A governed, compliant Azure environment baseline |
| **Management group** | Container above subscriptions for policy/RBAC at scale |
| **WAF** | Azure Well-Architected Framework |
