# Timberline Toss Academy (GCP deployment demo) — common tasks. Run `make` to list them.
# Checks run in pinned containers, so only Docker is required locally.

APP       := chainsaw_jugglers
IMAGE     ?= sample_code_3
TAG       ?= local
PORT      ?= 8081

NODE_IMAGE ?= node:24-slim
TF_IMAGE   ?= hashicorp/terraform:1.14
SC_IMAGE   ?= koalaman/shellcheck:stable
HADOLINT   ?= hadolint/hadolint:latest

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

# ── App ───────────────────────────────────────────────────────────────────────

.PHONY: install
install: ## Install app dependencies locally (npm ci)
	cd $(APP) && npm ci

.PHONY: run
run: install ## Run the site locally with auto-reload (http://localhost:8080)
	cd $(APP) && npm run dev

.PHONY: test
test: ## Run the app tests (Node 24 container)
	docker run --rm -v "$(CURDIR)/$(APP):/src:ro" $(NODE_IMAGE) sh -c \
		'cp -r /src /tmp/a && cd /tmp/a && rm -rf node_modules && npm ci --no-audit --no-fund >/dev/null && npm test'

.PHONY: audit
audit: ## npm audit of the production dependencies
	docker run --rm -v "$(CURDIR)/$(APP):/src:ro" $(NODE_IMAGE) sh -c \
		'cp -r /src /tmp/a && cd /tmp/a && npm audit --omit=dev'

# ── Infra / lint checks (containers; no cloud credentials, nothing is applied) ─

.PHONY: tf-check
tf-check: ## terraform fmt -check + init -backend=false + validate
	docker run --rm -v "$(CURDIR)/terraform:/src:ro" --entrypoint sh $(TF_IMAGE) -c \
		'cp -r /src /tmp/t && cd /tmp/t && terraform fmt -check -recursive && \
		 terraform init -backend=false -input=false -lockfile=readonly >/dev/null && terraform validate'

.PHONY: shellcheck
shellcheck: ## Lint shell scripts
	docker run --rm -v "$(CURDIR):/mnt:ro" -w /mnt $(SC_IMAGE) scripts/*.sh

.PHONY: hadolint
hadolint: ## Lint the Dockerfile
	docker run --rm -i $(HADOLINT) < Dockerfile

.PHONY: check
check: test audit tf-check shellcheck hadolint ## Everything CI runs

# ── Docker ────────────────────────────────────────────────────────────────────

.PHONY: docker-build
docker-build: ## Build the production image
	docker build -t $(IMAGE):$(TAG) .

.PHONY: docker-run
docker-run: docker-build ## Run the image read-only (http://127.0.0.1:8081)
	docker run --rm -p 127.0.0.1:$(PORT):8080 --read-only $(IMAGE):$(TAG)

.PHONY: up
up: ## docker compose up --build (http://127.0.0.1:8081)
	docker compose -f docker-compose.yml up --build

# ── GCP (real cloud; costs money) ─────────────────────────────────────────────

.PHONY: deploy
deploy: ## terraform apply + Cloud Run readiness + HTTPS probe (needs GCP creds)
	./scripts/runner.sh deploy

.PHONY: clean
clean: ## Remove local node_modules
	rm -rf $(APP)/node_modules
