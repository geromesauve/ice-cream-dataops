# Scripts de bootstrap CDF prod — ice-cream-dataops

Ces scripts corrigent le bug "SP prod n'a aucun accès à cdf-bootcamp-36-prod"
et déploient/mettent à jour les groupes `cognite_toolkit_service_principal`
et `data_developer` en production, avec gestion automatique de l'**upsert**
(si le groupe existe déjà, il est supprimé puis recréé avec les nouvelles
valeurs — l'API CDF Groups n'a pas de PATCH).

## Pré-requis

- `az` (Azure CLI) installé et accessible dans le PATH WSL
- `curl`, `python3` disponibles
- Un compte **humain** bootcamp ayant déjà confirmé son accès à l'UI Fusion
  sur **test ET prod** :
  - https://cog-enablement-bootcamp.fusion.cognite.com/cdf-bootcamp-36-test/access-management?cluster=westeurope-1.cognitedata.com&workspace=admin
  - https://cog-enablement-bootcamp.fusion.cognite.com/cdf-bootcamp-36-prod/access-management?cluster=westeurope-1.cognitedata.com&workspace=admin

## Ordre d'exécution

```bash
cd "/mnt/c/Users/J1145255/OneDrive - TotalEnergies/Documents/Projets/ice-cream-dataops"

# 1. Connexion interactive (device code) avec ton compte humain bootcamp
bash scripts/01_login_prod.sh

# 2. Création / mise à jour des groupes CDF prod (toolkit SP + data_developer)
#    Par défaut, utilise le sourceId confirmé 9f6ec900-4ce7-46cf-8b15-ede850f713ee
bash scripts/02_bootstrap_prod_groups.sh

# 3. Vérifier que les 3 SP prod (admin / icapi / oee) ont bien l'accès
#    (secrets à récupérer dans ton coffre / notes privées, NE PAS les committer)
export PROD_ADMIN_CLIENT_SECRET="<secret-admin-prod>"
export PROD_ICAPI_CLIENT_SECRET="<secret-icapi-prod>"
export PROD_OEE_CLIENT_SECRET="<secret-oee-prod>"
bash scripts/03_verify_prod_sp.sh

# 4. Corriger les variables GitHub prod (ICAPI_EXTRACTORS_SOURCE_ID, DATA_DEVELOPER_SOURCE_ID)
export GITHUB_TOKEN="ghp_xxx"   # ton PAT GitHub avec scope repo (NE PAS committer)
bash scripts/04_fix_github_prod_vars.sh

# 5. Relancer la GitHub Action "Deploy Toolkit" sur l'environnement prod
#    https://github.com/geromesauve/ice-cream-dataops/actions
#    -> Run workflow -> environment: prod -> Run
```

## Ce que fait chaque script

| Script | Rôle |
|---|---|
| `01_login_prod.sh` | Connexion `az login --use-device-code` au tenant bootcamp, vérifie l'accès CDF |
| `02_bootstrap_prod_groups.sh` | **Upsert** (create ou update) des groupes `cognite_toolkit_service_principal` et `data_developer` dans `cdf-bootcamp-36-prod` |
| `03_verify_prod_sp.sh` | Vérifie que les 3 Service Principals prod ont un accès effectif |
| `04_fix_github_prod_vars.sh` | Corrige les variables GitHub environment `prod` qui contenaient par erreur des *client secrets* au lieu des *source IDs* |

## Points connus / limitations

- Le SP **prod-oee** (`f4171299-...`) n'est encore membre d'**aucun groupe
  Entra** → son token n'a pas de claim `groups`. Il faut :
  1. Aller sur https://entra.microsoft.com → Groups
  2. Créer/retrouver le groupe Entra prod pour OEE
  3. Ajouter le SP OEE comme membre
  4. Mettre à jour `DATA_PIPELINE_OEE_SOURCE_ID` dans GitHub (prod) avec son
     Object ID

- Le groupe `icapi_extractors` et `data_pipeline_oee` ne sont PAS créés par
  ces scripts : ils seront déployés automatiquement par
  `cdf deploy --env prod` dès que `cognite_toolkit_service_principal` est en
  place (étape 2) — c'est le Toolkit qui les gère via les fichiers YAML du
  repo (`modules/bootcamp/.../auth/*.Group.yaml`).
