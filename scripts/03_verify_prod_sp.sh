#!/usr/bin/env bash
# ============================================================================
# 03_verify_prod_sp.sh
# Vérifie que les 3 Service Principals prod (admin, icapi, oee) ont bien
# un accès effectif à cdf-bootcamp-36-prod après le bootstrap.
#
# Usage :
#   bash scripts/03_verify_prod_sp.sh
# ============================================================================
set -euo pipefail

TOKEN_URL="https://login.microsoftonline.com/16e3985b-ebe8-4e24-9da4-933e21a9fc81/oauth2/v2.0/token"
SCOPE="https://westeurope-1.cognitedata.com/.default"
CDF_URL="https://westeurope-1.cognitedata.com"
PROJECT="cdf-bootcamp-36-prod"

check_sp() {
  local name="$1" client_id="$2" client_secret="$3"
  local token
  token=$(curl -s -X POST "$TOKEN_URL" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=client_credentials&client_id=${client_id}&client_secret=${client_secret}&scope=${SCOPE}" \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))")

  if [[ -z "$token" ]]; then
    echo "  ${name} : ❌ impossible d'obtenir un token (vérifie client_id/secret)"
    return
  fi

  local result
  result=$(curl -s "${CDF_URL}/api/v1/token/inspect" -H "Authorization: Bearer ${token}" \
    | python3 -c "
import sys, json
d = json.load(sys.stdin)
projects = [p.get('projectUrlName') for p in d.get('projects', [])]
groups = [g.get('name') for g in d.get('groups', [])]
print('projects=%s groups=%s' % (projects, groups))
")
  if [[ "$result" == *"${PROJECT}"* ]]; then
    echo "  ${name} : ✅ ${result}"
  else
    echo "  ${name} : ❌ PAS ENCORE d'accès -> ${result}"
  fi
}

echo "============================================================"
echo " Vérification des 3 SP prod sur ${PROJECT}"
echo "============================================================"
echo ""
echo "⚠️  Remplis les 3 secrets ci-dessous avant de lancer ce script"
echo "    (ils ne sont pas stockés dans ce fichier pour des raisons de sécurité)"
echo ""

: "${PROD_ADMIN_CLIENT_SECRET:?Exporte PROD_ADMIN_CLIENT_SECRET avant de lancer ce script}"
: "${PROD_ICAPI_CLIENT_SECRET:?Exporte PROD_ICAPI_CLIENT_SECRET avant de lancer ce script}"
: "${PROD_OEE_CLIENT_SECRET:?Exporte PROD_OEE_CLIENT_SECRET avant de lancer ce script}"

check_sp "prod-admin (13ed8bc0...)" "13ed8bc0-74fb-48ad-a2e3-f5b84d01d08e" "${PROD_ADMIN_CLIENT_SECRET}"
check_sp "prod-icapi (de56c989...)" "de56c989-a482-42a1-b379-8342c0a6088f" "${PROD_ICAPI_CLIENT_SECRET}"
check_sp "prod-oee   (f4171299...)" "f4171299-6f14-454b-8b06-3029722098bd" "${PROD_OEE_CLIENT_SECRET}"

echo ""
echo "Si prod-oee affiche '❌ PAS ENCORE d'accès', c'est normal : son SP"
echo "n'est membre d'aucun groupe Entra encore. Il faut :"
echo "  1. Aller sur https://entra.microsoft.com -> Groups"
echo "  2. Créer un groupe 'bootcamp-36-prod-oee-group' (ou réutiliser"
echo "     le groupe icapi 2e8f4311-8ce0-470d-acdf-a1a6fbe864f8 si tu veux"
echo "     aller plus vite, en ajoutant juste le SP OEE comme membre)"
echo "  3. Mettre le sourceId correspondant dans la variable GitHub"
echo "     DATA_PIPELINE_OEE_SOURCE_ID (voir script 04)"
