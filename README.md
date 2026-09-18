# Nginx GitOps Repository

Repository GitOps pour déployer Nginx dans trois environnements Kubernetes :

- DEV
- PREPROD
- PROD

Argo CD surveille ce repository et réconcilie automatiquement l'état du cluster avec Git.

## Arborescence

```text
nginx-gitops/
├── argocd/
│   ├── application-dev.yaml
│   ├── application-preprod.yaml
│   ├── application-prod.yaml
│   ├── kustomization.yaml
│   └── project.yaml
├── base/
│   ├── deployment.yaml
│   ├── kustomization.yaml
│   └── service.yaml
├── environments/
│   ├── dev/
│   │   ├── kustomization.yaml
│   │   └── namespace.yaml
│   ├── preprod/
│   │   ├── kustomization.yaml
│   │   └── namespace.yaml
│   └── prod/
│       ├── kustomization.yaml
│       └── namespace.yaml
└── README.md
```

## 1. Pré-requis

- Kubernetes / k3s
- kubectl
- Git
- Argo CD installé dans le namespace `argocd`

## 2. Configurer l'URL du repository Git

Remplacer dans tous les fichiers sous `argocd/` :

```text
REPLACE_WITH_GIT_REPOSITORY_URL
```

par exemple par :

```text
https://github.com/my-user/nginx-gitops.git
```

Commande Linux pratique :

```bash
grep -rl 'REPLACE_WITH_GIT_REPOSITORY_URL' argocd \
  | xargs sed -i 's#REPLACE_WITH_GIT_REPOSITORY_URL#https://github.com/my-user/nginx-gitops.git#g'
```

## 3. Vérifier les manifests Kustomize

```bash
kubectl kustomize environments/dev
kubectl kustomize environments/preprod
kubectl kustomize environments/prod
```

## 4. Bootstrap Argo CD

Créer les objets Argo CD :

```bash
kubectl apply -k argocd/
```

Vérifier :

```bash
kubectl get appprojects -n argocd
kubectl get applications -n argocd
```

## 5. Vérifier DEV

```bash
kubectl get all -n dev
```

Test local :

```bash
kubectl port-forward svc/nginx-dev 8080:80 -n dev
```

Puis :

```bash
curl http://localhost:8080
```

## 6. Monter la version Nginx en DEV

Modifier :

```text
environments/dev/kustomization.yaml
```

Par exemple :

```yaml
images:
  - name: nginx
    newName: nginx
    newTag: "1.28.1"
```

Puis :

```bash
git checkout -b upgrade/nginx-1.28.1
git add environments/dev/kustomization.yaml
git commit -m "chore(dev): upgrade nginx to 1.28.1"
git push -u origin upgrade/nginx-1.28.1
```

Créer ensuite une Pull Request vers `main`.

Après merge, Argo CD DEV détecte le changement et déploie automatiquement la nouvelle version.

## 7. Vérifier le rollout

```bash
kubectl rollout status deployment/nginx-dev -n dev
kubectl get pods -n dev
kubectl get deployment nginx-dev -n dev \
  -o jsonpath='{.spec.template.spec.containers[0].image}'; echo
```

## 8. Promotion vers PREPROD

Reporter exactement la même version dans :

```text
environments/preprod/kustomization.yaml
```

Exemple :

```yaml
newTag: "1.28.1"
```

Puis créer une nouvelle Pull Request :

```bash
git checkout -b promote/nginx-1.28.1-preprod
git add environments/preprod/kustomization.yaml
git commit -m "chore(preprod): promote nginx 1.28.1"
git push -u origin promote/nginx-1.28.1-preprod
```

Après merge, PREPROD est automatiquement synchronisé.

## 9. Promotion vers PROD

Modifier :

```text
environments/prod/kustomization.yaml
```

Puis créer une Pull Request :

```bash
git checkout -b promote/nginx-1.28.1-prod
git add environments/prod/kustomization.yaml
git commit -m "chore(prod): promote nginx 1.28.1"
git push -u origin promote/nginx-1.28.1-prod
```

Après merge, l'application Argo CD PROD devient `OutOfSync`.

La synchronisation PROD reste volontairement manuelle :

```bash
argocd app sync nginx-prod
```

ou via l'interface Argo CD.

## 10. Rollback GitOps

Le rollback recommandé consiste à revenir sur le commit Git ayant modifié la version :

```bash
git log --oneline
git revert <commit-id>
git push
```

Argo CD réconciliera ensuite le cluster avec la version restaurée dans Git.

Éviter d'utiliser `kubectl rollout undo` comme mécanisme permanent de rollback GitOps, car Git resterait sur une version différente et Argo CD pourrait remettre la version déclarée dans le repository.

## 11. Politique de promotion conseillée

```text
DEV
  │
  │ Merge PR
  ▼
Auto Sync
  │
  ▼
Validation
  │
  ▼
PR PREPROD
  │
  ▼
Auto Sync
  │
  ▼
Validation
  │
  ▼
PR PROD
  │
  ▼
Manual Sync / Approval
```

## 12. Commandes utiles

Lister les applications :

```bash
kubectl get applications -n argocd
```

Voir le statut :

```bash
kubectl get application nginx-dev -n argocd
kubectl get application nginx-preprod -n argocd
kubectl get application nginx-prod -n argocd
```

Voir les pods :

```bash
kubectl get pods -n dev
kubectl get pods -n preprod
kubectl get pods -n prod
```

Voir les images réellement utilisées :

```bash
kubectl get deployments -A \
  -o custom-columns='NAMESPACE:.metadata.namespace,DEPLOYMENT:.metadata.name,IMAGE:.spec.template.spec.containers[*].image'
```
