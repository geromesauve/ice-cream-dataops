#!/usr/bin/env bash
# ============================================================================
# 01_login_prod.sh
#
# ⚠️ `az login --scope <resource>` ne fonctionne PAS dans ce tenant :
#    l'app "Microsoft Azure CLI" (04b07795-...) n'a aucune ressource
#    pré-autorisée (AADSTS650057 : "List of valid resources from app
#    registration: ." = liste vide). C'est un verrou côté tenant bootcamp,
#    impossible à contourner avec az CLI.
#
# SOLUTION : récupérer le token d'accès CDF directement depuis TON
# NAVIGATEUR, où l'app Fusion (qui a déjà le consentement) le génère pour
# toi à chaque requête. Ce script affiche juste la procédure ; il n'y a
# rien à exécuter côté az.
#
# Usage :
#   bash scripts/01_login_prod.sh      # affiche la procédure
# ============================================================================
set -euo pipefail

cat <<'EOF'
============================================================
 Récupération manuelle du token CDF prod depuis le navigateur
============================================================

1. Ouvre cette URL dans ton navigateur (connecté avec ton compte bootcamp) :

   https://cog-enablement-bootcamp.fusion.cognite.com/cdf-bootcamp-36-prod/access-management?cluster=westeurope-1.cognitedata.com&workspace=admin

2. Ouvre les DevTools (touche F12) -> onglet "Network" (Réseau)

3. Rafraîchis la page (F5). Des requêtes vers
   "westeurope-1.cognitedata.com" doivent apparaître dans la liste.

4. Clique sur une de ces requêtes (ex: "token/inspect", "groups", ou
   n'importe quel appel vers /api/v1/projects/cdf-bootcamp-36-prod/...)

5. Dans l'onglet "Headers" de la requête, trouve la ligne :

      Authorization: Bearer eyJ0eXAiOiJKV1QiLC...

   Copie UNIQUEMENT la partie après "Bearer " (le long texte qui commence
   par eyJ...)

6. Exporte-le dans ton terminal WSL :

      export HUMAN_TOKEN="eyJ0eXAiOiJKV1QiLC..."

7. Lance ensuite :

      bash scripts/02_bootstrap_prod_groups.sh

============================================================
 Note : ce token expire généralement après ~1h. Si un script
 échoue avec une erreur 401, recommence depuis l'étape 1.
============================================================
EOF
