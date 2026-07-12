guinea-go/                      ← racine du repo
├── backend/
│   ├── app/
│   │   ├── core/              # config, sécurité, middlewares
│   │   ├── common/            # utilitaires partagés (pagination, exceptions...)
│   │   ├── database/          # connexion MongoDB, Motor client
│   │   ├── identity/          # Auth, Users
│   │   ├── shared/            # Countries, Cities, Currencies
│   │   ├── modules/
│   │   │   ├── transport/
│   │   │   │   ├── companies/
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