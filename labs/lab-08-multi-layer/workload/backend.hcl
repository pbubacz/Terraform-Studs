# From Lab 4 bootstrap outputs. key MUST be workload.tfstate for this layer.
resource_group_name  = "rg-tfcourse-ab-tfstate"
storage_account_name = "sttfcourseabtfstate"
container_name       = "tfstate"
key                  = "workload.tfstate"
use_azuread_auth     = true
