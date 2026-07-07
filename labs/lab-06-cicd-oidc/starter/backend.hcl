# Backend config for `terraform init -backend-config=backend.hcl`
# (used locally and by the GitHub Actions workflow). Match the storage you
# created in Part 1B step 2. The Azure DevOps pipeline passes these values via
# the TerraformTask inputs instead.
resource_group_name  = "rg-tfcourse-ab-tfstate"
storage_account_name = "sttfcourseabtfstate"
container_name       = "tfstate"
key                  = "lab06.tfstate"
use_azuread_auth     = true
