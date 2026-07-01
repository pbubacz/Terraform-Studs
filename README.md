# Student Handbook — Terraform on Azure (2-Day Course)

Welcome! This handbook is your single reference for the two days. It covers what
you'll learn, how to set up, the lab path, key commands, troubleshooting and a
glossary. Your hands-on work lives in `labs/` — start each lab from its own
`README.md`.

---

## 1. What you'll learn

By the end of this course you will be able to:

1. Explain Terraform's declarative model and run the core workflow.
2. Write idiomatic HCL with variables, locals, outputs, expressions and functions.
3. Authenticate the AzureRM provider safely.
4. Manage remote state in Azure Blob Storage with locking.
5. Refactor safely using `import`, `moved` and `removed`.
6. Author, publish and consume modules using composition.


---

## 2. Course map

### Day 1 — Foundations to production basics
| Module | Topic | Lab |
|--------|-------|-----|
| M1 | IaC & Terraform mental model | Lab 0 (setup) |
| M2 | Core workflow & AzureRM provider | – |
| M3 | HCL essentials | Lab 1 |
| M4 | Expressions, functions & the console | Lab 2 |
| M5 | Refactoring: import / moved / removed | Lab 3 |
| M6 | State management with Azure Blob | Lab 4 |
| M7 | Dependencies & authoring modules | Lab 5 |


---

## 3. Setup (do once, before Lab 0)


| Tool | Purpose | Verification | Links |
|------|---------|--------------|-------|
| Terraform CLI (≥ 1.7) | Core engine | `terraform version` | https://developer.hashicorp.com/terraform/downloads |
| Azure CLI | Auth + subscription | `az login`, `az account show` | https://learn.microsoft.com/cli/azure/install-azure-cli |
| VS Code | Code editor | `code --version` | https://code.visualstudio.com/download |
| HashiCorp Terraform Extension for VS Code | Terraform authoring | Extension installed | https://marketplace.visualstudio.com/items?itemName=HashiCorp.terraform |
| Git | Version control | `git --version` | https://git-scm.com/downloads |
| tfsec | Terraform static analysis | `tfsec --version` | https://aquasecurity.github.io/tfsec/latest/guides/installation/ |
| Checkov (alternative to tfsec) | Terraform static analysis | `checkov --version` | https://www.checkov.io/2.Basics/Installing%20Checkov.html |


| Tool | Purpose | Verify |
|------|---------|--------|
| Terraform CLI (≥ 1.7) | Core engine | `terraform version` |
| Azure CLI | Auth + subscription | `az login`, `az account show` |
| VS Code + HashiCorp Terraform extension | Authoring | extension installed |
| Git | Version control | `git --version` |
| GitHub or Azure DevOps account | Day-2 pipelines | repo access |
| tfsec **or** Checkov | Static analysis | `tfsec --version` |

### Sign in and select your subscription
```bash
az login
az account set --subscription "<subscription-id>"
az account show -o table        # confirm the SANDBOX subscription
```

### Set your per-student values (PowerShell)
```powershell
$env:TF_VAR_prefix   = "tfcourse-ab"     # use YOUR initials
$env:TF_VAR_location = "polandcentral"
$env:TF_VAR_owner    = "ab@example.com"
```

> The AzureRM provider reuses your `az login` context for local labs. OIDC
> (secretless) is introduced in Lab 6 for pipelines.

---

## 4. Conventions used in all labs

| Item | Convention |
|------|-----------|
| Region | `polandcentral` (override with `var.location`) |
| Naming prefix | `tfcourse-<your-initials>` |
| Resource group | `rg-tfcourse-<initials>-<env>` |
| Storage account | lowercase, no dashes, ≤ 24 chars |
| Tags | `course = "terraform-azure"`, `owner`, `env` |
| Terraform | `>= 1.7` |
| AzureRM provider | `~> 4.0` |

> ⚠️ Everything runs in a **sandbox**. Run `terraform destroy` after each lab to
> control cost.

---

## 5. How to work a lab

1. Open the lab's `README.md` (e.g., `labs/lab-01-first-resources/README.md`).
2. Write your own code in the `starter/` folder.
3. Run the workflow:
   ```bash
   terraform init
   terraform fmt
   terraform validate
   terraform plan -out=tfplan
   terraform apply tfplan
   ```
4. Check the **expected deliverables** and validation commands.
5. Only peek at `solution/` once you've tried — then compare.
6. Tear down: `terraform destroy`.

### Lab path & dependencies
| Lab | Title | Difficulty | Depends on |
|-----|-------|-----------|------------|
| 0 | Environment verification | ⭐ | – |
| 1 | First Azure resources | ⭐ | 0 |
| 2 | Expressions, functions & `for_each` | ⭐⭐ | 1 |
| 3 | Safe refactoring | ⭐⭐ | 1 |
| 4 | Expressions, functions & dynamic blocks | ⭐⭐⭐ | 2 |
| 5 | Author & compose a module | ⭐⭐ | 2, 4 |


---

## 6. Key commands cheat-sheet

```bash
terraform init                 # download providers, configure backend
terraform init -backend-config=backend.hcl   # supply backend settings (Lab 4+)
terraform fmt -recursive       # canonical formatting
terraform validate             # syntax + internal consistency
terraform plan -out=tfplan     # preview changes, save plan
terraform apply tfplan         # apply the saved plan
terraform destroy              # tear everything down

terraform console              # REPL for expressions / state inspection
terraform state list           # list resources in state
terraform state show <addr>    # inspect one resource

az login                       # sign in to Azure
az account show -o table       # show current subscription
tfsec .   |   checkov -d .      # static analysis (shift-left)
```

### Useful console expressions (try in `terraform console`)
```hcl
> cidrsubnet("10.40.0.0/16", 8, 1)
> merge({ env = "dev" }, { owner = "ab" })
> { for n in ["web", "db"] : n => upper(n) }
> coalesce("", null, "fallback")
```

---

## 7. Key concepts you'll meet (in order)

| Day/Module | Concept | One-liner |
|------------|---------|-----------|
| M1 | State | Terraform's record of what it manages. |
| M2 | Plan symbols | `+` create, `~` update, `-` destroy, `-/+` replace. |
| M3 | Variables/locals/outputs | Inputs, computed values, results. |
| M4 | `for_each` vs `count` | Stable keys vs. index churn — prefer `for_each`. |
| M5 | `import`/`moved`/`removed` | Change **state**, not Azure. |


> **AVM note:** current Azure Verified Modules take `parent_id` (the resource
> group **ID**), not `resource_group_name`. Always copy inputs from the module's
> registry page for the pinned version.

---

## 8. Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| `Error acquiring the state lock` | Concurrent run / stale lease | Wait; only break the lease if no run is active |
| `AADSTS...` auth error | Wrong tenant/subscription or expired login | `az login`; `az account set` |
| Plan shows unexpected **destroy/replace** | Rename without a `moved` block | Add a `moved` block |
| `Backend initialization required` | Backend config changed | `terraform init -reconfigure` |
| Backend init fails on storage | No RBAC on the state storage | Assign `Storage Blob Data Contributor` |
| Storage account name rejected | Invalid name | 3–24 chars, lowercase letters/numbers only |
| Provider version keeps changing | Lock file not committed | Commit `.terraform.lock.hcl` |
| OIDC pipeline `401` / `AADSTS70021` | Federated credential `subject` mismatch | Match `repo:org/repo:ref:refs/heads/main` or environment |
| AVM module: "resource_group_name not expected" | Old interface | Use `parent_id = <rg>.id` instead |
| `quota exceeded` on apply | Sandbox limits | Use smaller SKUs / fewer instances |

---

## 9. Glossary

| Term | Meaning |
|------|---------|
| **Provider** | Plugin mapping Terraform resources to an API (e.g., `azurerm`). |
| **Resource** | A managed infrastructure object. |
| **Data source** | Read-only lookup of existing infrastructure. |
| **State** | Terraform's record of resources it manages. |
| **Backend** | Where state is stored (local, or Azure Blob = remote). |
| **Lock** | Prevents concurrent state writes (blob lease). |
| **Plan / Apply** | Preview vs. execute changes. |
| **Drift** | Difference between real infra and recorded state. |
| **Module** | Reusable container of resources with an input/output contract. |
| **Root module** | The directory where you run `terraform`. |
| **`for_each` / `count`** | Meta-arguments to create multiple instances. |
| **`depends_on`** | Explicit dependency when no reference exists. |
| **`import` / `moved` / `removed`** | Adopt, rename, or release resources without destroy. |
| **Remote state** | State stored centrally for team use. |
| **OIDC / workload identity** | Secretless federated auth for pipelines. |
| **Shift-left** | Catching issues early (validate, scan) before deploy. |
| **Policy as code** | Governance rules expressed and enforced as code. |
| **AVM** | Azure Verified Modules — Microsoft-owned, tested standard modules. |
| **Resource / Pattern / Utility module** | The three AVM module classes. |
| **Landing zone** | A governed, compliant Azure environment baseline. |
| **Management group** | Container above subscriptions for policy/RBAC at scale. |
| **WAF** | Azure Well-Architected Framework. |

---

## 10. After the course (keep learning)

- Testing: `terraform test`, Terratest.
- Terraform Cloud / HCP, Sentinel policy.
- Azure Landing Zone Accelerator (management groups, policy at scale).
- Deeper AVM: Pattern modules, interface contracts, telemetry, WAF alignment.

Happy building! 🚀
