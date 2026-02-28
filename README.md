# gitops

GitOps repository — single source of truth for all Kubernetes deployments.
ArgoCD watches this repo and reconciles the cluster to match what's defined here.

## Structure

```
charts/app/          Generic Helm chart — used by all standard services
apps/<name>/         Per-app values files (image tag updated by CI)
argocd/install/      ArgoCD Helm install overrides
argocd/projects/     ArgoCD AppProject definitions (RBAC scoping)
argocd/applications/ ArgoCD Application manifests per env
environments/        Namespace and cluster-level manifests
```

## Adding a new service

1. Add `apps/<service-name>/values.yaml` with base values
2. Add `apps/<service-name>/values-dev.yaml` with env overrides
3. Add `argocd/applications/dev/<service-name>.yaml` ArgoCD Application manifest
4. Apply the ArgoCD Application to the cluster

## Helm chart

The generic chart in `charts/app/` works for any standard HTTP service.
Sourced from an existing production chart — see `charts/app/` for full documentation.

## CI integration

After a successful image build, CI updates `apps/<name>/values-dev.yaml`:

```yaml
image:
  tag: <new-sha>   # set by CI pipeline
```

ArgoCD detects the change and syncs automatically.

------

Here is the full simple explanation — no jargon, just what it is and why it exists.

---

## What is the `gitops` repo and why does it exist?

### The core problem it solves

Right now you have a CI pipeline that:
1. Takes your code from `hello-world-api`
2. Builds a Docker image
3. Pushes it to ACR

But nothing actually **deploys** that image to Kubernetes. Someone (or something) needs to tell AKS: *"Hey, run this new image."* That's where the `gitops` repo comes in.

---

### The idea behind GitOps in one sentence

> **Git is the single source of truth for what should be running in your cluster.**

Instead of running `kubectl apply` manually, you write what you *want* deployed into a Git repo. ArgoCD watches that repo and automatically makes the cluster match what's written there. If the cluster drifts (someone manually changes something), ArgoCD corrects it back.

---

### What we built — layer by layer

#### Layer 1: The Generic Helm Chart (`charts/app/`)

```
charts/
└── app/
    ├── Chart.yaml          ← chart identity (name, version)
    ├── values.yaml         ← default settings (all features OFF by default)
    └── templates/          ← the actual Kubernetes YAML generators
        ├── deployment.yaml
        ├── service-versioned.yaml
        ├── httproute.yaml  ← creates the APISIX route
        ├── hpa.yaml        ← auto-scaling
        ├── configmap.yaml
        ├── secret.yaml
        └── ... (15 templates total)
```

Think of this as a **blank form**. It knows how to create a Deployment, a Service, an HTTPRoute, etc. — but it has no idea about `hello-world-api` specifically. It just knows: *"tell me the app name, image, port, hostname and I'll generate all the Kubernetes YAML for you."*

One chart. Reused for every service you ever add.

---

#### Layer 2: App-specific config (`apps/<service>/`)

```
apps/
├── hello-world-api/
│   ├── values.yaml         ← "fill in the form" for this specific app
│   └── values-dev.yaml     ← dev-only overrides (e.g. image tag)
└── hello-world-frontend/
    ├── values.yaml
    └── values-dev.yaml
```

`values.yaml` says things like:
- App name is `hello-world-api`
- Image is `ampliordevacr.azurecr.io/hello-world-api`
- Port is `5000`
- Route traffic from `dev-apis.ampliorinternal.com` through APISIX

`values-dev.yaml` says:
- Use image tag `latest` ← **CI will update this line automatically on every build**

These two files together, combined with the generic chart, produce all the Kubernetes YAML needed to run `hello-world-api` in AKS.

---

#### Layer 3: ArgoCD wiring (`argocd/`)

```
argocd/
├── install/values.yaml         ← how ArgoCD itself is configured
├── projects/knor-project.yaml  ← permission boundary (what repos/clusters are allowed)
└── applications/dev/
    ├── hello-world-api.yaml    ← tells ArgoCD: "watch this chart + these values"
    └── hello-world-frontend.yaml
```

An **ArgoCD Application** is a simple YAML file that says:

> "Watch `charts/app/` + `apps/hello-world-api/values.yaml` + `apps/hello-world-api/values-dev.yaml` in the `gitops` repo. When anything changes, deploy it to the `dev` namespace in AKS."

That's it. Once this is applied, ArgoCD handles all deploys automatically.

---

#### Layer 4: Environment config (`environments/`)

```
environments/
├── dev/
│   └── namespace.yaml   ← creates the "dev" namespace in Kubernetes
└── prod/
    └── .gitkeep
```

Just the Kubernetes namespace definition. Applied once to create the `dev` namespace where everything runs.

---

### The full flow end-to-end

```
Developer merges PR
        ↓
GitHub Actions (CI) builds Docker image → pushes to ACR
        ↓
CI updates image.tag in apps/hello-world-api/values-dev.yaml → commits to gitops repo
        ↓
ArgoCD detects the change in gitops repo (polls every ~3 mins)
        ↓
ArgoCD runs: helm template charts/app + apps/hello-world-api/values.yaml + values-dev.yaml
        ↓
ArgoCD applies the resulting Kubernetes YAML to AKS
        ↓
AKS pulls the new image from ACR and starts the new pod
```

**No manual `kubectl` commands. No SSH. No manual Helm runs.** You merge code → it gets deployed.

---

### Why is this better than just running `kubectl apply` from CI?

| Problem with `kubectl` from CI | How GitOps solves it |
|---|---|
| No audit trail of what's deployed | Every deploy is a Git commit with author + timestamp |
| If CI breaks, nobody knows what's actually running | Git = ground truth, cluster always matches it |
| Hard to roll back | Just revert a commit in gitops repo |
| Dev and prod configs scattered across pipeline files | All in one place, per environment |
| Secrets/config changes require editing pipeline | Just edit values files, ArgoCD picks it up |

---

The **missing piece** right now is Step 4 from the last message — the CI pipeline doesn't yet write the new image tag into `values-dev.yaml`. Once that's done and the ArgoCD Application manifests are filled in, the entire loop is closed and fully automated. Want to proceed with that?
