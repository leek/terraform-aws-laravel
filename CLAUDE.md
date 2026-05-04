# Laravel AWS Terraform Infrastructure

Production-grade AWS infra for Laravel apps. ECS Fargate + RDS/Aurora + Redis + S3 + SQS, with HIPAA-ready compliance modules.

## Commands

All workflows go through the `Makefile`. `make help` lists them.

```bash
# Terraform (env = staging | uat | production)
make terraform.init
make terraform.<env>.plan
make terraform.<env>.apply        # production has NO -auto-approve

# Docker build + ECR push + ECS redeploy in one shot
make docker.<env>.build
make docker.<env>.push            # tags :latest, pushes, force-redeploys all ECS services

# AWS / ECS
make aws.login
make aws.<env>.redeploy           # force-redeploy + wait for stable
make aws.<env>.ssh                # ECS Exec into the `app` container

# Bastion (only if enable_bastion=true in tfvars)
make bastion.<env>.ssh            # uses ~/.ssh/<APP_NAME>-bastion-key.pem

# Git-branch deploy trigger
make git.<env>.deploy             # force-pushes current main to <env> branch
```

## Layout

- `terraform/main.tf` — root module wiring 19 sub-modules.
- `terraform/modules/` — `bastion cache certificates client_vpn compliance compute configuration container_registry database dns email load_balancer meilisearch messaging monitoring networking security storage`.
- `terraform/environments/*.tfvars` — **gitignored**; only `example.tfvars` is committed. Copy it to `staging.tfvars` etc. before planning.
- `docker/Dockerfile` — 3-stage build (binaries → builder → production). PHP 8.4 with Swoole, RoadRunner, FrankenPHP pre-installed; pick mode at runtime via supervisord conf.
- `docker/supervisord-*.conf` — one per role (web, web-octane-{swoole,roadrunner,frankenphp}, queue-worker, scheduler).

## Gotchas

- **Workspace must match `var.environment`.** `main.tf` has a precondition that fails the apply if `terraform.workspace != var.environment`. Makefile auto-selects/creates the workspace per target.
- **Three ECS services per env**: `<app>-<env>-service`, `<app>-<env>-queue-worker`, `<app>-<env>-scheduler`. Hardcoded in `Makefile:21` (`ECS_SERVICES`); update there if you add more.
- **`Makefile.config`** (gitignored, see `Makefile.config.example`) overrides `APP_NAME`, `AWS_PROFILE`, `AWS_REGION`, `DOCKER_PLATFORM`, etc. without editing `Makefile`.
- **Production apply runs without `-auto-approve`** (`Makefile:82`) — needs interactive confirmation. Don't add `-auto-approve` back.
- **Docker push pushes `:latest` only** (`Makefile:107`). No image versioning; rollback = redeploy a previous task definition manually.
- **App key is sensitive tfvar** (`variables.tf:17`). Never commit `*.tfvars` outside `example.tfvars`.

## Linting / CI

- `.tflint.hcl`, `.checkov.yaml` configured at root.
- GitHub Actions: `tfsec`, `checkov`, `hadolint`, `shellcheck`, dependabot auto-merge (`.github/workflows/`).
