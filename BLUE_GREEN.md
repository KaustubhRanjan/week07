# SIT722 Task 10.3HD – Zero-Downtime Blue/Green Deployment (course-service)

This extends the Week 07 CI pipeline into full **continuous delivery**. Every push to `main` now:

```
tests ──► build & push image (tag = commit SHA)
            │
            ▼
   deploy to STAGING slot  ──►  smoke tests  ──✗──► STOP (production untouched)
                                    │ ✓
                                    ▼
                     swap STAGING ⇄ PRODUCTION (zero downtime)
                                    │
                                    ▼
                          verify PRODUCTION ──✗──► automatic swap back
```

## What was added

| File | Purpose |
|---|---|
| `course-service/app/main.py` | `/health` now checks the database and returns `version` (commit SHA) and `slot` (staging/production). Returns 503 if the DB is down. |
| `course-service/Dockerfile` | `APP_VERSION` build arg baked into the image. |
| `course-service/tests/test_health.py` | Unit test for the new health response. |
| `terraform/app_service.tf` | S1 App Service plan, course-service web app + `staging` slot, PostgreSQL Flexible Server + `courses` DB, health check, swap warm-up, sticky `SLOT_NAME`. |
| `terraform/variables.tf`, `output.tf`, `versions.tf`, `terraform.tfvars` | New variables/outputs, `random` provider. |
| `.github/workflows/ci.yml` | Passes `APP_VERSION` into builds; new `deploy-course-service` job. |
| `.github/workflows/rollback.yml` | Manual one-click rollback (swaps slots back). |
| `scripts/smoke_test.sh` | Release gate – waits for the new version then checks health, DB, routes, auth, latency. |
| `scripts/watch_prod.sh` / `scripts/watch_prod.ps1` | Hits production every 0.5 s and counts failures – for the demo video. |

---

## Step 1 – Fill in `terraform/terraform.tfvars`

```hcl
acr_name             = "koalatechacrkr1716"        # your ACR name (letters/numbers only)
storage_account_name = "koalatechstkr1716"         # 3-24 lowercase letters/numbers
course_app_name      = "koalatech-course-kr1716"   # lowercase, numbers, hyphens
```

All three must be globally unique. If you already have an ACR and storage account from Week 07, use the same names.

## Step 2 – Create the Azure resources

```powershell
az login
cd terraform
terraform init -upgrade
terraform plan
terraform apply
```

Takes about 5–10 minutes (PostgreSQL is the slow part). When it finishes, note the outputs:

```powershell
terraform output
```

> **Cost:** S1 plan + B1ms PostgreSQL cost roughly A$4–5 per day. Run `terraform destroy` when you finish each session.
>
> If PostgreSQL fails with a "location is restricted" error, add `postgres_location = "Australia Southeast"` (or another region) to `terraform.tfvars` and apply again.

## Step 3 – Push an initial image (first time only)

The web app starts from `koalatech-course-service:latest`. If your ACR is new/empty, run the pipeline once (Step 5) – the deploy job will put the proper image in place. Before that, the slots will show an error page; that is expected.

## Step 4 – GitHub settings

Your service principal (from Week 07, stored in `AZURE_CREDENTIALS`) must be allowed to manage the web app, not just ACR. Give it **Contributor on the resource group**:

```powershell
az role assignment create `
  --assignee <clientId from AZURE_CREDENTIALS> `
  --role Contributor `
  --scope /subscriptions/<subscriptionId>/resourceGroups/koalatech-week07-rg
```

Then in GitHub → **Settings → Secrets and variables → Actions → Variables**, add:

| Variable | Value |
|---|---|
| `RESOURCE_GROUP` | `koalatech-week07-rg` |
| `COURSE_WEBAPP_NAME` | value of `terraform output course_web_app_name` |

(`ACR_NAME`, `ACR_LOGIN_SERVER` and the `AZURE_CREDENTIALS` secret already exist from Week 07 – check `ACR_LOGIN_SERVER` matches your current ACR.)

## Step 5 – Run it

Merge `feature/blue-green` into `main` and push (or run the workflow manually from the Actions tab on `main`). Watch **Blue/Green deploy course-service** in Actions. At the end, the job summary shows the version in production and staging.

Check it yourself:

```
https://<course_app_name>.azurewebsites.net/health          → slot: production, version: <new sha>
https://<course_app_name>-staging.azurewebsites.net/health  → slot: staging,    version: <previous sha>
```

---

## Demo for the video

### A. Successful zero-downtime release

1. Open a terminal and start the watcher:
   ```powershell
   .\scripts\watch_prod.ps1 https://<course_app_name>.azurewebsites.net
   ```
   (Git Bash: `bash scripts/watch_prod.sh https://<course_app_name>.azurewebsites.net`)
2. Make a harmless change, e.g. edit the message in the `/` endpoint in `course-service/app/main.py`, commit, push to `main`.
3. Show the Actions run side by side with the watcher. After the swap the watcher prints `<== VERSION CHANGED` while `fail=0` stays at zero.
4. Press Ctrl+C for the summary (e.g. `600 OK, 0 failed`).

### B. Bad release blocked by the gate

Introduce a bug the unit tests don't cover – for example in `course-service/app/main.py`:

```python
@app.get("/", tags=["Health"])
def root() -> dict[str, str]:
    raise RuntimeError("simulated regression")
```

Push to `main`. Unit tests still pass and the image builds, but **Smoke test STAGING** fails on `/ -> 500`, the swap step is skipped, and the watcher shows production still on the old version with `fail=0`. Revert the change and push again to finish in a good state.

### C. Manual rollback (optional)

Actions → **Rollback course-service** → Run workflow. Production swaps back to the previous version in seconds.

---

## Design notes (for the write-up)

- **Why slots:** both versions run side by side on the same plan; the swap is a routing change after Azure has warmed the new instance on `/health` (`WEBSITE_SWAP_WARMUP_PING_PATH`), so no requests are dropped.
- **Immutable versions:** images are tagged with the commit SHA and the SHA is baked into the image, so `/health` proves exactly which build each slot runs.
- **Sticky setting:** `SLOT_NAME` stays with its slot; everything else is identical in both slots so a swap causes no config drift.
- **Terraform vs pipeline ownership:** Terraform ignores `application_stack`, so `terraform apply` never rolls the running image back.
- **Limitations:** both slots share one database, so schema changes must be backward-compatible (expand/contract). Only course-service is blue/green in this version; the same pattern extends to other services with a `for_each` in Terraform and a matrix in the deploy job.
- **Cleanup:** `terraform destroy` after each session.
