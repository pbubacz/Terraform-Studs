# Lab 08 — Multi-Team, Multi-Layer Architecture with AVM

- **Duration:** 90 min · **Difficulty:** ⭐⭐⭐ · **Depends on:** Lab 04, 06, 07

## Scenario
Two teams, two layers, two state files:
- **Platform team** owns shared networking (a hub VNet via an AVM module).
- **Workload team** deploys an app that **consumes** the platform via
  `terraform_remote_state` — never the other way around.

```
lab-08-multi-layer/
├─ platform/    -> backend key = platform.tfstate   (platform team owns)
└─ workload/    -> backend key = workload.tfstate    (app team owns)
```

## Prerequisites
- A state backend from Lab 4 (`bootstrap/`). Reuse its storage account.

## Tasks

### Layer 1 — Platform (deploy first)
1. In `platform/`, fill `backend.hcl` (key = `platform.tfstate`).
2. Deploy the hub VNet via the AVM module and expose outputs:
   ```bash
   cd platform
   terraform init -backend-config=backend.hcl
   terraform apply
   terraform output       # resource_group_name, vnet_id, vnet_name, subnet_names, location
   ```

### Layer 2 — Workload (deploy second)
1. In `workload/`, fill `backend.hcl` (key = `workload.tfstate`) and set the
   `platform_state_*` variables to point at the platform state.
2. The workload reads platform outputs via `terraform_remote_state` and places a
   NIC into a platform subnet:
   ```bash
   cd ../workload
   terraform init -backend-config=backend.hcl
   terraform apply
   ```

## Expected deliverables
- Two independently-stated layers in the same state container (different keys).
- The workload consuming platform outputs and looking up the subnet ID at apply time.
- A clean one-way dependency: workload → platform.

## Discussion
- Where do ownership/RBAC boundaries sit between the layers?
- What breaks if the platform changes a subnet name? (Output contract stability.)
- How would a third team add another workload layer?

## Anti-patterns to call out
- One giant state for everything (huge blast radius, slow plans).
- Circular dependencies between layers.

## Cleanup
Destroy `workload/` first, then `platform/`.
