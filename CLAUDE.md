guinea-go/                      ← racine du repo
├── backend/
│   ├── app/
│   │   ├── core/              # config, sécurité, middlewares
│   │   ├── common/            # utilitaires partagés (pagination, exceptions...)
│   │   ├── database/          # connexion MongoDB, Motor client
│   │   ├── identity/          # Auth, Users
│   │   ├── shared/            # Countries, Cities, Currencies
│   │   ├── modules/
│   │   │   ├── companies/     # partagé par transport, hôtels, événements, écoles, commerces
│   │   │   ├── transport/
│   │   │   │   ├── buses/
│   │   │   │   ├── drivers/
│   │   │   │   ├── stations/
│   │   │   │   ├── routes/
│   │   │   │   ├── schedules/
│   │   │   │   └── trips/
│   │   │   ├── hotels/
│   │   │   ├── events/
│   │   │   ├── education/
│   │   │   └── commerce/
│   │   ├── payments/
│   │   ├── notifications/
│   │   ├── analytics/
│   │   └── admin/
│   ├── requirements.txt (ou pyproject.toml)
│   └── .env
├── mobile/                     # app Flutter — codebase unique, compilée pour mobile ET web (targets mobile + web)
├── admin_dashboard/            # projet Flutter Web séparé, dédié au dashboard admin (platform_admin)
├── CLAUDE.md                   # ce fichier — contexte du projet pour Claude Code
└── README.md

## Rôles utilisateurs (RBAC)

Source de vérité unique : `backend/app/core/constants.py::UserRole`. Toute autre définition des rôles ailleurs dans le code est obsolète et doit être alignée sur celle-ci.

| Rôle (code) | Nom | Capacités principales |
|---|---|---|
| `passenger` | Passenger | S'inscrire, se connecter, rechercher des trajets, réserver des tickets, payer, recevoir des tickets QR, consulter son historique de réservations |
| `company_owner` | Company Owner | Créer des compagnies, gérer bus/chauffeurs/stations/routes/horaires, consulter les rapports |
| `driver` | Driver | Voir les trajets assignés, scanner les tickets des passagers, mettre à jour le statut du trajet, recevoir des notifications |
| `hotel_owner` | Hotel Owner | Gérer hôtels/chambres/réservations, consulter les rapports d'occupation |
| `event_organizer` | Event Organizer | Créer des événements, vendre des billets, générer des QR codes, suivre la fréquentation |
| `school_administrator` | School Administrator | Gérer élèves/enseignants/classes/examens/présences/frais scolaires |
| `store_manager` | Store Manager | Gérer inventaire/produits/fournisseurs/clients/factures, générer des rapports |
| `system_administrator` | System Administrator | Accès complet à tous les modules et à la configuration système |

`system_administrator` a un accès total et contourne les vérifications `require_role`/`require_permission`. L'inscription publique (`POST /auth/register`) attribue toujours le rôle `passenger` — les autres rôles sont attribués via des flux de création dédiés (à venir).

## Données de référence (`backend/app/shared/`)

- **`countries/`, `cities/`, `currencies`** : actifs, montés dans `main.py`. Lecture publique (GET), écriture réservée à `system_administrator` (POST — il n'y a pas encore de PUT/DELETE). `Country.currency_id` référence un vrai document `Currency` (résolu depuis un `currency_code` fourni en entrée) ; `City.country_code` reste une clé texte simple vers `Country.code`, pas un `country_id`. Seedées au démarrage (`database/seed.py::run_seed`) : devises GNF/XOF/GHS, pays GN/SN/GH, quelques villes.
- **`languages/`, `locations/`** : scaffolds mis de côté, non montés dans `main.py`, non exposés par l'API. `languages/` n'a que ses schémas (`LanguageCreate`/`LanguageResponse`), aucun router/service/repository ; `locations/` est entièrement vide. À construire seulement quand un besoin réel apparaît (ex: filtrage par langue préférée, données géographiques au-delà de ville/pays) — ne pas les monter tels quels.
- **Aucun module métier (transport/hôtels/événements/commerce/éducation) ne référence `shared/` par clé étrangère.** `country_code`/`city` y sont des champs texte libres, par convention seulement (jamais validés contre `countries`/`cities`). Les montants (`price`, `amount`, `total`, ...) sont des `float` nus, sans devise associée — seul `Payment.currency` existe, et il est actuellement codé en dur à `"GNF"` dans `PaymentService`, indépendamment de `shared/currencies`.