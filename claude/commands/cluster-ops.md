# Cluster Ops

Scoped operations on Kubernetes clusters and ArgoCD — always bound to one cluster + one ArgoCD project at a time.

## Environment assumptions

Assume the following are already in place — do NOT install, configure, or verify them preemptively:

- `kubectl` is installed and on `$PATH`
- `argocd` CLI is installed and on `$PATH`
- The user has valid kubeconfig contexts for the target clusters
- The user is already authenticated to ArgoCD (or will be via an existing context)

If a command fails due to missing auth or context, surface the exact error and ask the user how to proceed — do not attempt to re-authenticate silently.

## Instructions

**IMPORTANT — Gather scope first, confirm via table, execute after approval.**

### Step 1 — Collect scope inputs

Before running ANY `kubectl` or `argocd` command, ask the user for (unless already provided via `$ARGUMENTS` or recent conversation):

1. **Cluster** — which Kubernetes cluster / kubeconfig context (e.g. `benedita-k8s`, `firmino-prod`)
2. **ArgoCD Project** — which ArgoCD project to scope changes to (e.g. `benedita`, `firmino`)
3. **Namespace(s)** — optional, if the task is namespace-specific
4. **Objective** — what the user wants to do (sync an app, check drift, patch a resource, restart a deployment, update manifests, etc.)

If the user already stated any of these in the request, reuse them and only ask for what's missing.

### Step 2 — Confirmation table

ALWAYS present this table before executing anything, so the user can verify you understood the inputs correctly:

```
| Field              | Value                         |
|--------------------|-------------------------------|
| Cluster (context)  | <kubeconfig context>          |
| ArgoCD Project     | <project>                     |
| Namespace(s)       | <namespaces or "all">         |
| Objective          | <what will be done>           |
| Scope boundary     | <project>/<cluster> only      |
| Planned commands   | <key kubectl / argocd cmds>   |
| Out-of-scope note  | <any change outside the scope, explicitly called out — otherwise "none"> |
```

Wait for explicit approval ("ok", "sim", "go", "confirma", etc.) before moving on.

### Step 3 — Execute with hard scope

During execution, enforce these rules:

1. **Every `kubectl` command must pin the context**: `kubectl --context=<cluster> ...`. Do not rely on `current-context`.
2. **Every `argocd` command that targets an app/resource must pin the project filter** when listing (`argocd app list --project <project>`) or verify the app's `.spec.project` matches before acting.
3. **Only touch resources owned by the confirmed ArgoCD project**. Before `kubectl patch/delete/apply`, confirm the target resource is managed by an ArgoCD Application whose `.spec.project == <project>`. If it isn't, STOP and flag it.
4. **File edits (manifests / Helm values / Kustomize overlays)**: only modify paths that belong to the confirmed project/environment. If the task requires editing a shared or cross-project path (e.g. a shared base, a different environment, an `argocd` namespace resource), STOP and make this *extremely* evident:
   - Explicitly call it out in bold: "⚠️ This change falls OUTSIDE the `<project>` scope and touches `<other scope>` because `<reason>`."
   - Ask the user to confirm the scope expansion before proceeding.
5. **Destructive operations** (`delete`, `--force`, `--cascade=orphan`, `argocd app delete`, disabling auto-sync, `--replace`, hard refreshes that may cause prune): require a second explicit confirmation from the user, even after Step 2 approval.
6. **Read-only recon first**: when diagnosing, start with read-only commands (`get`, `describe`, `logs`, `argocd app get`, `argocd app diff`) before any mutation.

### Step 4 — Report

After execution, summarize:
- What ran (commands + key outputs, truncated)
- Resulting state (app health/sync status, pod status, whatever is relevant)
- Anything still pending or requiring follow-up

## Useful command reference

Pin these patterns — do not drift from them:

```bash
# Kubernetes (always with --context)
kubectl --context=<cluster> -n <ns> get pods
kubectl --context=<cluster> -n <ns> describe <kind>/<name>
kubectl --context=<cluster> -n <ns> logs <pod> [-c <container>] [--tail=200]
kubectl --context=<cluster> -n <ns> rollout restart deploy/<name>
kubectl --context=<cluster> -n <ns> apply -f <file>
kubectl --context=<cluster> -n <ns> diff -f <file>

# ArgoCD (always scope to project)
argocd app list --project <project>
argocd app get <app>
argocd app diff <app>
argocd app sync <app> [--prune] [--force]
argocd app wait <app> --health --timeout 300
argocd app history <app>
argocd app rollback <app> <revision>
argocd app manifests <app>
argocd app resources <app>
argocd proj get <project>
```

## Arguments

`$ARGUMENTS` (optional) may preseed scope. Accepted shorthand:
- `cluster=<ctx> project=<proj>` → preseed both
- `<project>/<cluster>` → shorthand for project and cluster when names align

If `$ARGUMENTS` is empty, always ask. Never guess cluster/project names from the working directory or git state.

## Hard rules (never violate)

1. Never run a mutating command before Step 2 approval.
2. Never operate across multiple clusters or projects in a single invocation without an explicit scope-expansion confirmation.
3. Never skip the confirmation table, even if the user sounds in a hurry.
4. Never assume the kubeconfig `current-context` — always pin with `--context`.
5. Never delete or disable ArgoCD Applications, AppProjects, or sync policies without double confirmation.
