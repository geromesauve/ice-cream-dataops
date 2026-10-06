#!/usr/bin/env bash
# ============================================================================
# 04_fix_github_prod_vars.sh
# Corrige les variables GitHub de l'environnement 'prod' qui ont été
# accidentellement remplies avec des CLIENT SECRETS au lieu des SOURCE IDs
# (Object ID du groupe Entra).
#
# Valeurs corrigées automatiquement :
#   - ICAPI_EXTRACTORS_SOURCE_ID  = 2e8f4311-8ce0-470d-acdf-a1a6fbe864f8
#                                   (lue depuis le claim "groups" du token
#                                   OAuth du SP prod-icapi)
#   - DATA_DEVELOPER_SOURCE_ID    = 9f6ec900-4ce7-46cf-8b15-ede850f713ee
#                                   (groupe Entra prod dédié confirmé)
#
# Valeur NON corrigée automatiquement (le SP prod-oee n'est encore membre
# d'aucun groupe Entra -> à créer d'abord, voir script 03) :
#   - DATA_PIPELINE_OEE_SOURCE_ID -> laissé tel quel, à corriger manuellement
#     une fois le groupe Entra OEE créé.
#
# Pré-requis : exporter un token GitHub avec les scopes repo + workflow :
#   export GITHUB_TOKEN=ghp_xxx
#
# Usage :
#   export GITHUB_TOKEN=ghp_xxx
#   DATA_DEVELOPER_SOURCE_ID_PROD=<objectId-si-different> bash scripts/04_fix_github_prod_vars.sh
# ============================================================================
set -euo pipefail

: "${GITHUB_TOKEN:?Exporte GITHUB_TOKEN=ghp_xxx avant de lancer ce script}"

REPO="geromesauve/ice-cream-dataops"
ENV="prod"
DATA_DEVELOPER_SOURCE_ID_PROD="${DATA_DEVELOPER_SOURCE_ID_PROD:-9f6ec900-4ce7-46cf-8b15-ede850f713ee}"
ICAPI_SOURCE_ID_PROD="2e8f4311-8ce0-470d-acdf-a1a6fbe864f8"

update_var() {
  local name="$1" value="$2"
  echo "  -> ${name} = ${value}"
  curl -s -o /dev/null -w "     HTTP %{http_code}\n" -X PATCH \
    "https://api.github.com/repos/${REPO}/environments/${ENV}/variables/${name}" \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"${name}\",\"value\":\"${value}\"}"
}

echo "============================================================"
echo " Correction des variables GitHub (env: ${ENV})"
echo "============================================================"

echo ""
echo "1. ICAPI_EXTRACTORS_SOURCE_ID (groupe Entra confirmé via token SP)"
update_var "ICAPI_EXTRACTORS_SOURCE_ID" "${ICAPI_SOURCE_ID_PROD}"

echo ""
echo "2. DATA_DEVELOPER_SOURCE_ID (groupe Entra prod dédié confirmé)"
update_var "DATA_DEVELOPER_SOURCE_ID" "${DATA_DEVELOPER_SOURCE_ID_PROD}"

echo ""
echo "⚠️  DATA_PIPELINE_OEE_SOURCE_ID n'est PAS corrigée automatiquement."
echo "    Le SP prod-oee n'appartient encore à aucun groupe Entra."
echo "    Une fois le groupe créé (voir script 03), lance :"
echo ""
echo "    curl -X PATCH \\"
echo "      https://api.github.com/repos/${REPO}/environments/${ENV}/variables/DATA_PIPELINE_OEE_SOURCE_ID \\"
echo "      -H \"Authorization: token \$GITHUB_TOKEN\" \\"
echo "      -H \"Content-Type: application/json\" \\"
echo "      -d '{\"name\":\"DATA_PIPELINE_OEE_SOURCE_ID\",\"value\":\"<objectId-du-groupe>\"}'"

echo ""
echo "============================================================"
echo " État final des variables prod"
echo "============================================================"
curl -s "https://api.github.com/repos/${REPO}/environments/${ENV}/variables?per_page=50" \
  -H "Authorization: token ${GITHUB_TOKEN}" \
  | python3 -c "
import sys, json
for v in json.load(sys.stdin).get('variables', []):
    print('  %-32s = %s' % (v['name'], v['value']))
"
