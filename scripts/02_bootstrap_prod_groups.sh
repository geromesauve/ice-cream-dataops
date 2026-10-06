#!/usr/bin/env bash
# ============================================================================
# 02_bootstrap_prod_groups.sh
# Crée OU MET A JOUR les groupes CDF nécessaires dans cdf-bootcamp-36-prod,
# en utilisant le token humain obtenu via 01_login_prod.sh (az login déjà actif).
#
# L'API CDF Groups n'a pas de PUT/PATCH : "mettre à jour" un groupe =
# supprimer l'ancien (par son id) puis recréer un nouveau avec le même nom,
# le nouveau sourceId et les nouvelles capabilities. Ce script fait cet
# upsert automatiquement : si un groupe du même nom existe déjà, il est
# supprimé puis recréé avec les valeurs ci-dessous.
#
# Groupes gérés :
#   1. cognite_toolkit_service_principal
#        -> sourceId = d9cdeee1-8eda-4ade-946f-fdb824d0b716
#           (groupe Entra dont le SP bootcamp-36-prod-admin-tk-app est membre
#            - vérifié via le claim "groups" du token du SP)
#        -> capabilities = EXACTE copie du groupe équivalent en test
#
#   2. data_developer
#        -> sourceId = valeur de $DATA_DEVELOPER_SOURCE_ID_PROD
#           (par défaut : 9f6ec900-4ce7-46cf-8b15-ede850f713ee,
#            le groupe Entra prod dédié confirmé)
#        -> capabilities = EXACTE copie collée par toi
#
# NE crée PAS encore 'icapi_extractors' ni 'data_pipeline_oee' : ceux-là
# seront déployés automatiquement par 'cdf deploy --env prod' une fois que
# le SP prod-admin a accès via le groupe toolkit (étape 1 ci-dessus).
#
# Usage :
#   export HUMAN_TOKEN="<token copié depuis le navigateur, voir 01_login_prod.sh>"
#   bash scripts/02_bootstrap_prod_groups.sh
#   # ou pour forcer un autre sourceId data_developer :
#   DATA_DEVELOPER_SOURCE_ID_PROD=<objectId> bash scripts/02_bootstrap_prod_groups.sh
# ============================================================================
set -euo pipefail

CDF_URL="https://westeurope-1.cognitedata.com"
PROJECT="cdf-bootcamp-36-prod"

TOOLKIT_GROUP_SOURCE_ID="d9cdeee1-8eda-4ade-946f-fdb824d0b716"
DATA_DEVELOPER_SOURCE_ID_PROD="${DATA_DEVELOPER_SOURCE_ID_PROD:-9f6ec900-4ce7-46cf-8b15-ede850f713ee}"

: "${HUMAN_TOKEN:?Exporte HUMAN_TOKEN=<token du navigateur> avant de lancer ce script. Voir scripts/01_login_prod.sh}"
TOKEN="${HUMAN_TOKEN}"

echo "============================================================"
echo " Vérification de l'accès au projet prod avec le token fourni"
echo "============================================================"
INSPECT=$(curl -s "${CDF_URL}/api/v1/token/inspect" -H "Authorization: Bearer ${TOKEN}")
echo "$INSPECT" | python3 -m json.tool
PROJECTS=$(echo "$INSPECT" | python3 -c "import sys,json; print(' '.join(p.get('projectUrlName','') for p in json.load(sys.stdin).get('projects',[])))" 2>/dev/null || true)

if [[ "$PROJECTS" != *"$PROJECT"* ]]; then
  echo ""
  echo "⚠️  Ce token n'a pas accès à ${PROJECT}."
  echo "    Connecte-toi d'abord à l'UI Fusion prod avec ce même compte :"
  echo "    https://cog-enablement-bootcamp.fusion.cognite.com/${PROJECT}/access-management?cluster=westeurope-1.cognitedata.com&workspace=admin"
  echo "    Si tu y as accès via l'UI, relance ce script (le token sera mis à jour)."
  exit 1
fi

# ----------------------------------------------------------------------------
# Fonction d'upsert : supprime le groupe existant (même nom) s'il existe,
# puis crée un nouveau groupe avec le JSON passé en 2e argument (via stdin).
# ----------------------------------------------------------------------------
upsert_group() {
  local group_name="$1"
  local payload_file="$2"

  echo "  Recherche d'un groupe existant nommé '${group_name}'..."
  local existing_id
  existing_id=$(curl -s "${CDF_URL}/api/v1/projects/${PROJECT}/groups?all=true" \
    -H "Authorization: Bearer ${TOKEN}" \
    | python3 -c "
import sys, json
d = json.load(sys.stdin)
for g in d.get('items', []):
    if g.get('name') == '${group_name}':
        print(g.get('id'))
        break
")

  if [[ -n "$existing_id" ]]; then
    echo "  -> Groupe existant trouvé (id=${existing_id}). Suppression avant recréation..."
    curl -s -X POST "${CDF_URL}/api/v1/projects/${PROJECT}/groups/delete" \
      -H "Authorization: Bearer ${TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{\"items\": [${existing_id}]}" | python3 -m json.tool || true
  else
    echo "  -> Aucun groupe existant. Création directe."
  fi

  echo "  Création du groupe '${group_name}' avec les nouvelles valeurs..."
  curl -s -X POST "${CDF_URL}/api/v1/projects/${PROJECT}/groups" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d @"${payload_file}" | python3 -m json.tool
}

# ----------------------------------------------------------------------------
# 1/2 cognite_toolkit_service_principal
# ----------------------------------------------------------------------------
echo ""
echo "============================================================"
echo " 1/2 Upsert du groupe 'cognite_toolkit_service_principal'"
echo "============================================================"

TOOLKIT_PAYLOAD=$(mktemp)
cat > "${TOOLKIT_PAYLOAD}" <<JSON
{
  "items": [{
    "name": "cognite_toolkit_service_principal",
    "sourceId": "${TOOLKIT_GROUP_SOURCE_ID}",
    "capabilities": [
      {"projectsAcl": {"actions": ["LIST","READ","UPDATE"], "scope": {"all": {}}}},
      {"groupsAcl": {"actions": ["LIST","READ","CREATE","UPDATE","DELETE"], "scope": {"all": {}}}},
      {"dataModelInstancesAcl": {"actions": ["WRITE","READ"], "scope": {"all": {}}}},
      {"dataModelsAcl": {"actions": ["WRITE","READ"], "scope": {"all": {}}}},
      {"datasetsAcl": {"actions": ["OWNER","WRITE","READ"], "scope": {"all": {}}}},
      {"eventsAcl": {"actions": ["WRITE","READ"], "scope": {"all": {}}}},
      {"extractionPipelinesAcl": {"actions": ["WRITE","READ"], "scope": {"all": {}}}},
      {"filesAcl": {"actions": ["WRITE","READ"], "scope": {"all": {}}}},
      {"functionsAcl": {"actions": ["WRITE","READ"], "scope": {"all": {}}}},
      {"hostedExtractorsAcl": {"actions": ["WRITE","READ"], "scope": {"all": {}}}},
      {"labelsAcl": {"actions": ["WRITE","READ"], "scope": {"all": {}}}},
      {"locationFiltersAcl": {"actions": ["WRITE","READ"], "scope": {"all": {}}}},
      {"rawAcl": {"actions": ["WRITE","LIST","READ"], "scope": {"all": {}}}},
      {"roboticsAcl": {"actions": ["CREATE","DELETE","UPDATE","READ"], "scope": {"all": {}}}},
      {"securityCategoriesAcl": {"actions": ["CREATE","MEMBEROF","LIST","UPDATE","DELETE"], "scope": {"all": {}}}},
      {"sequencesAcl": {"actions": ["WRITE","READ"], "scope": {"all": {}}}},
      {"sessionsAcl": {"actions": ["CREATE","DELETE","LIST"], "scope": {"all": {}}}},
      {"threedAcl": {"actions": ["CREATE","DELETE","UPDATE","READ"], "scope": {"all": {}}}},
      {"timeSeriesAcl": {"actions": ["WRITE","READ"], "scope": {"all": {}}}},
      {"timeSeriesSubscriptionsAcl": {"actions": ["WRITE","READ"], "scope": {"all": {}}}},
      {"transformationsAcl": {"actions": ["WRITE","READ"], "scope": {"all": {}}}},
      {"workflowOrchestrationAcl": {"actions": ["WRITE","READ"], "scope": {"all": {}}}}
    ]
  }]
}
JSON

upsert_group "cognite_toolkit_service_principal" "${TOOLKIT_PAYLOAD}"
rm -f "${TOOLKIT_PAYLOAD}"

# ----------------------------------------------------------------------------
# 2/2 data_developer
# ----------------------------------------------------------------------------
echo ""
echo "============================================================"
echo " 2/2 Upsert du groupe 'data_developer'"
echo "============================================================"
echo "sourceId utilisé : ${DATA_DEVELOPER_SOURCE_ID_PROD}"

DATADEV_PAYLOAD=$(mktemp)
cat > "${DATADEV_PAYLOAD}" <<JSON
{
  "items": [{
    "name": "data_developer",
    "sourceId": "${DATA_DEVELOPER_SOURCE_ID_PROD}",
    "capabilities": [
      {"dataModelInstancesAcl": {"actions": ["READ","WRITE"], "scope": {"all": {}}}},
      {"dataModelsAcl": {"actions": ["READ","WRITE"], "scope": {"all": {}}}},
      {"datasetsAcl": {"actions": ["READ","WRITE","OWNER"], "scope": {"all": {}}}},
      {"eventsAcl": {"actions": ["READ","WRITE"], "scope": {"all": {}}}},
      {"extractionConfigsAcl": {"actions": ["READ","WRITE"], "scope": {"all": {}}}},
      {"extractionPipelinesAcl": {"actions": ["READ","WRITE"], "scope": {"all": {}}}},
      {"extractionRunsAcl": {"actions": ["READ","WRITE"], "scope": {"all": {}}}},
      {"filesAcl": {"actions": ["READ","WRITE"], "scope": {"all": {}}}},
      {"functionsAcl": {"actions": ["READ","WRITE"], "scope": {"all": {}}}},
      {"hostedExtractorsAcl": {"actions": ["READ","WRITE"], "scope": {"all": {}}}},
      {"labelsAcl": {"actions": ["READ","WRITE"], "scope": {"all": {}}}},
      {"projectsAcl": {"actions": ["LIST","READ"], "scope": {"all": {}}}},
      {"rawAcl": {"actions": ["READ","WRITE","LIST"], "scope": {"all": {}}}},
      {"securityCategoriesAcl": {"actions": ["LIST","MEMBEROF","DELETE","CREATE","UPDATE"], "scope": {"all": {}}}},
      {"sessionsAcl": {"actions": ["LIST","CREATE","DELETE"], "scope": {"all": {}}}},
      {"timeSeriesAcl": {"actions": ["READ","WRITE"], "scope": {"all": {}}}},
      {"timeSeriesSubscriptionsAcl": {"actions": ["READ","WRITE"], "scope": {"all": {}}}},
      {"transformationsAcl": {"actions": ["READ","WRITE"], "scope": {"all": {}}}},
      {"workflowOrchestrationAcl": {"actions": ["READ","WRITE"], "scope": {"all": {}}}}
    ]
  }]
}
JSON

upsert_group "data_developer" "${DATADEV_PAYLOAD}"
rm -f "${DATADEV_PAYLOAD}"

# ----------------------------------------------------------------------------
echo ""
echo "============================================================"
echo " Vérification finale : liste des groupes dans ${PROJECT}"
echo "============================================================"
curl -s "${CDF_URL}/api/v1/projects/${PROJECT}/groups?all=true" \
  -H "Authorization: Bearer ${TOKEN}" \
  | python3 -c "
import sys, json
d = json.load(sys.stdin)
for g in d.get('items', []):
    print('  name=%-35s sourceId=%s' % (g.get('name'), g.get('sourceId')))
"

echo ""
echo "✅ Bootstrap/mise à jour terminé(e). Le SP prod-admin (13ed8bc0-...)"
echo "   devrait maintenant avoir accès à ${PROJECT} via le groupe"
echo "   cognite_toolkit_service_principal, et data_developer est à jour."
echo ""
echo "Prochaine étape : bash scripts/03_verify_prod_sp.sh"
