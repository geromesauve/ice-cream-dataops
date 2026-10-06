# %% [markdown]
# # Bootstrap CDF prod — `cdf-bootcamp-36-prod`
#
# Notebook à exécuter **en local** dans Jupyter (ou VS Code "Interactive
# Window" / Jupytext — les cellules sont délimitées par `# %%`).
#
# ## Pourquoi ce notebook plutôt que `az login` ?
# Dans ce tenant bootcamp, l'app "Microsoft Azure CLI" n'a **aucune
# ressource pré-autorisée** vers l'API CDF (`AADSTS650057`). Il est donc
# impossible d'obtenir un token CDF via `az account get-access-token`.
#
# Ce notebook contourne le problème en utilisant **ton token de session
# Fusion**, copié manuellement depuis le navigateur (où l'app Fusion a,
# elle, déjà le consentement nécessaire).
#
# ## Étape manuelle préalable (à faire une seule fois)
# 1. Ouvre dans ton navigateur, connecté avec ton compte bootcamp :
#    https://cog-enablement-bootcamp.fusion.cognite.com/cdf-bootcamp-36-prod/access-management?cluster=westeurope-1.cognitedata.com&workspace=admin
# 2. Ouvre les DevTools (`F12`) → onglet **Network**
# 3. Rafraîchis la page (`F5`)
# 4. Clique sur une requête vers `westeurope-1.cognitedata.com`
# 5. Dans l'onglet **Headers**, copie la valeur après `Authorization: Bearer `
# 6. Colle-la dans la variable `HUMAN_TOKEN` ci-dessous (cellule suivante)
#
# ⚠️ Ce token expire après ~1h. Si une cellule échoue avec 401, recommence
# cette étape et relance depuis le début du notebook.

# %%
# Installation (à exécuter une seule fois si cognite-sdk n'est pas déjà installé)
# !pip install cognite-sdk

# %%
import json

from cognite.client import CogniteClient
from cognite.client.config import ClientConfig
from cognite.client.credentials import Token
from cognite.client.data_classes import GroupList, GroupWrite
from cognite.client.exceptions import CogniteAPIError

# ============================================================================
# 1) Colle ici le token copié depuis le navigateur (sans le mot "Bearer")
# ============================================================================
HUMAN_TOKEN = "COLLE_TON_TOKEN_ICI_eyJ0eXAiOiJKV1Qi..."

CLUSTER = "westeurope-1"
PROJECT = "cdf-bootcamp-36-prod"
BASE_URL = f"https://{CLUSTER}.cognitedata.com"

client = CogniteClient(
    ClientConfig(
        client_name="bootstrap-prod-notebook",
        project=PROJECT,
        base_url=BASE_URL,
        credentials=Token(HUMAN_TOKEN),
    )
)

# %% [markdown]
# ## 2) Vérifier que le token donne bien accès à `cdf-bootcamp-36-prod`

# %%
inspect = client.iam.token.inspect()
print("Projets accessibles :", [p.project_url_name for p in inspect.projects])
print("Capabilities (count):", len(inspect.capabilities) if inspect.capabilities else 0)

assert PROJECT in [p.project_url_name for p in inspect.projects], (
    f"❌ Ce token n'a pas accès à {PROJECT}. "
    "Reprends l'étape manuelle (copie du token) décrite plus haut."
)
print(f"✅ Accès confirmé à {PROJECT}")

# %% [markdown]
# ## 3) Définition des groupes à créer / mettre à jour
#
# L'API CDF Groups n'a pas de PATCH : "mettre à jour" = supprimer l'ancien
# groupe (par id) puis en recréer un nouveau avec les mêmes name et les
# nouvelles valeurs sourceId / capabilities. La fonction `upsert_group`
# ci-dessous gère ça automatiquement.

# %%
TOOLKIT_GROUP_SOURCE_ID = "d9cdeee1-8eda-4ade-946f-fdb824d0b716"  # Entra group du SP bootcamp-36-prod-admin-tk-app
DATA_DEVELOPER_SOURCE_ID = "9f6ec900-4ce7-46cf-8b15-ede850f713ee"  # Entra group data developer prod confirmé

TOOLKIT_SP_CAPABILITIES = [
    {"projectsAcl": {"actions": ["LIST", "READ", "UPDATE"], "scope": {"all": {}}}},
    {"groupsAcl": {"actions": ["LIST", "READ", "CREATE", "UPDATE", "DELETE"], "scope": {"all": {}}}},
    {"dataModelInstancesAcl": {"actions": ["WRITE", "READ"], "scope": {"all": {}}}},
    {"dataModelsAcl": {"actions": ["WRITE", "READ"], "scope": {"all": {}}}},
    {"datasetsAcl": {"actions": ["OWNER", "WRITE", "READ"], "scope": {"all": {}}}},
    {"eventsAcl": {"actions": ["WRITE", "READ"], "scope": {"all": {}}}},
    {"extractionPipelinesAcl": {"actions": ["WRITE", "READ"], "scope": {"all": {}}}},
    {"filesAcl": {"actions": ["WRITE", "READ"], "scope": {"all": {}}}},
    {"functionsAcl": {"actions": ["WRITE", "READ"], "scope": {"all": {}}}},
    {"hostedExtractorsAcl": {"actions": ["WRITE", "READ"], "scope": {"all": {}}}},
    {"labelsAcl": {"actions": ["WRITE", "READ"], "scope": {"all": {}}}},
    {"locationFiltersAcl": {"actions": ["WRITE", "READ"], "scope": {"all": {}}}},
    {"rawAcl": {"actions": ["WRITE", "LIST", "READ"], "scope": {"all": {}}}},
    {"roboticsAcl": {"actions": ["CREATE", "DELETE", "UPDATE", "READ"], "scope": {"all": {}}}},
    {"securityCategoriesAcl": {"actions": ["CREATE", "MEMBEROF", "LIST", "UPDATE", "DELETE"], "scope": {"all": {}}}},
    {"sequencesAcl": {"actions": ["WRITE", "READ"], "scope": {"all": {}}}},
    {"sessionsAcl": {"actions": ["CREATE", "DELETE", "LIST"], "scope": {"all": {}}}},
    {"threedAcl": {"actions": ["CREATE", "DELETE", "UPDATE", "READ"], "scope": {"all": {}}}},
    {"timeSeriesAcl": {"actions": ["WRITE", "READ"], "scope": {"all": {}}}},
    {"timeSeriesSubscriptionsAcl": {"actions": ["WRITE", "READ"], "scope": {"all": {}}}},
    {"transformationsAcl": {"actions": ["WRITE", "READ"], "scope": {"all": {}}}},
    {"workflowOrchestrationAcl": {"actions": ["WRITE", "READ"], "scope": {"all": {}}}},
]

DATA_DEVELOPER_CAPABILITIES = [
    {"dataModelInstancesAcl": {"actions": ["READ", "WRITE"], "scope": {"all": {}}}},
    {"dataModelsAcl": {"actions": ["READ", "WRITE"], "scope": {"all": {}}}},
    {"datasetsAcl": {"actions": ["READ", "WRITE", "OWNER"], "scope": {"all": {}}}},
    {"eventsAcl": {"actions": ["READ", "WRITE"], "scope": {"all": {}}}},
    {"extractionConfigsAcl": {"actions": ["READ", "WRITE"], "scope": {"all": {}}}},
    {"extractionPipelinesAcl": {"actions": ["READ", "WRITE"], "scope": {"all": {}}}},
    {"extractionRunsAcl": {"actions": ["READ", "WRITE"], "scope": {"all": {}}}},
    {"filesAcl": {"actions": ["READ", "WRITE"], "scope": {"all": {}}}},
    {"functionsAcl": {"actions": ["READ", "WRITE"], "scope": {"all": {}}}},
    {"hostedExtractorsAcl": {"actions": ["READ", "WRITE"], "scope": {"all": {}}}},
    {"labelsAcl": {"actions": ["READ", "WRITE"], "scope": {"all": {}}}},
    {"projectsAcl": {"actions": ["LIST", "READ"], "scope": {"all": {}}}},
    {"rawAcl": {"actions": ["READ", "WRITE", "LIST"], "scope": {"all": {}}}},
    {"securityCategoriesAcl": {"actions": ["LIST", "MEMBEROF", "DELETE", "CREATE", "UPDATE"], "scope": {"all": {}}}},
    {"sessionsAcl": {"actions": ["LIST", "CREATE", "DELETE"], "scope": {"all": {}}}},
    {"timeSeriesAcl": {"actions": ["READ", "WRITE"], "scope": {"all": {}}}},
    {"timeSeriesSubscriptionsAcl": {"actions": ["READ", "WRITE"], "scope": {"all": {}}}},
    {"transformationsAcl": {"actions": ["READ", "WRITE"], "scope": {"all": {}}}},
    {"workflowOrchestrationAcl": {"actions": ["READ", "WRITE"], "scope": {"all": {}}}},
]

GROUPS_TO_UPSERT = [
    {
        "name": "cognite_toolkit_service_principal",
        "sourceId": TOOLKIT_GROUP_SOURCE_ID,
        "capabilities": TOOLKIT_SP_CAPABILITIES,
    },
    {
        "name": "data_developer",
        "sourceId": DATA_DEVELOPER_SOURCE_ID,
        "capabilities": DATA_DEVELOPER_CAPABILITIES,
    },
]


# %% [markdown]
# ## 4) Fonction d'upsert (create ou update)

# %%
def upsert_group(client: CogniteClient, name: str, source_id: str, capabilities: list[dict]) -> None:
    """Supprime le groupe existant du même nom (s'il existe) puis en recrée un nouveau."""
    existing = [g for g in client.iam.groups.list(all=True) if g.name == name]
    if existing:
        ids = [g.id for g in existing]
        print(f"  -> Groupe '{name}' existant (id={ids}). Suppression avant recréation...")
        client.iam.groups.delete(ids)
    else:
        print(f"  -> Aucun groupe '{name}' existant. Création directe.")

    new_group = GroupWrite.load({"name": name, "sourceId": source_id, "capabilities": capabilities})
    created = client.iam.groups.create(new_group)
    print(f"  ✅ Groupe '{name}' créé avec id={created.id}, sourceId={created.source_id}")


# %% [markdown]
# ## 5) Exécution de l'upsert pour les 2 groupes

# %%
for g in GROUPS_TO_UPSERT:
    print(f"\n=== Upsert '{g['name']}' ===")
    try:
        upsert_group(client, g["name"], g["sourceId"], g["capabilities"])
    except CogniteAPIError as e:
        print(f"  ❌ Erreur API : {e}")

# %% [markdown]
# ## 6) Vérification finale : liste de tous les groupes du projet prod

# %%
all_groups: GroupList = client.iam.groups.list(all=True)
for g in all_groups:
    print(f"  name={g.name:<35} sourceId={g.source_id}")

# %% [markdown]
# ## 7) (Optionnel) Vérifier l'accès effectif des 3 Service Principals prod
#
# Nécessite leurs client_secret (à coller ci-dessous, ne pas committer ce
# notebook avec des secrets en clair !).

# %%
import urllib.parse
import urllib.request

TENANT_ID = "16e3985b-ebe8-4e24-9da4-933e21a9fc81"
TOKEN_URL = f"https://login.microsoftonline.com/{TENANT_ID}/oauth2/v2.0/token"
SCOPE = f"{BASE_URL}/.default"

SP_TO_CHECK = {
    "prod-admin": ("13ed8bc0-74fb-48ad-a2e3-f5b84d01d08e", "COLLE_SECRET_ADMIN_ICI"),
    "prod-icapi": ("de56c989-a482-42a1-b379-8342c0a6088f", "COLLE_SECRET_ICAPI_ICI"),
    "prod-oee": ("f4171299-6f14-454b-8b06-3029722098bd", "COLLE_SECRET_OEE_ICI"),
}


def check_sp_access(client_id: str, client_secret: str) -> dict:
    data = urllib.parse.urlencode(
        {
            "grant_type": "client_credentials",
            "client_id": client_id,
            "client_secret": client_secret,
            "scope": SCOPE,
        }
    ).encode()
    with urllib.request.urlopen(urllib.request.Request(TOKEN_URL, data=data)) as r:
        token = json.load(r)["access_token"]

    req = urllib.request.Request(
        f"{BASE_URL}/api/v1/token/inspect", headers={"Authorization": f"Bearer {token}"}
    )
    with urllib.request.urlopen(req) as r:
        return json.load(r)


for name, (cid, secret) in SP_TO_CHECK.items():
    if "COLLE_SECRET" in secret:
        print(f"{name:12} : (secret non renseigné, skip)")
        continue
    info = check_sp_access(cid, secret)
    projects = [p["projectUrlName"] for p in info.get("projects", [])]
    status = "✅" if PROJECT in projects else "❌"
    print(f"{name:12} : {status} projects={projects}")

# %% [markdown]
# ## Prochaines étapes
# 1. Relance la GitHub Action "Deploy Toolkit" sur l'environnement **prod** :
#    https://github.com/geromesauve/ice-cream-dataops/actions
# 2. Si `prod-oee` affiche ❌ ci-dessus, il faut créer un groupe Entra pour
#    ce SP (voir `scripts/03_verify_prod_sp.sh` pour le détail) et mettre à
#    jour la variable GitHub `DATA_PIPELINE_OEE_SOURCE_ID`.
