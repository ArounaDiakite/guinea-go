# Guinea Go Platform Architecture

## Vision

Guinea Go est une plateforme digitale multi-services destinée à évoluer comme une Super App.

Elle commencera par :
- Transport
- Hôtels
- Événements

Puis évoluera vers :
- Gestion scolaire
- Gestion commerciale
- Paiements
- Notifications
- Analytics

## Architecture globale

app/
│
├── core/
│   ├── config.py
│   ├── security.py
│   └── dependencies.py
│
├── common/
│   └── base_model.py
│
├── database/
│   ├── mongodb.py
│   ├── indexes.py
│   ├── seed.py
│   └── startup.py
│
├── identity/
│   ├── auth/
│   └── users/
│
├── shared/
│   ├── countries/
│   ├── cities/
│   ├── currencies/
│   ├── languages/
│   ├── locations/
│   └── uploads/
│
├── modules/
│   ├── companies/
│   ├── transport/
│   │   ├── buses/
│   │   ├── routes/
│   │   ├── trips/
│   │   ├── seats/
│   │   ├── bookings/
│   │   └── tickets/
│   │
│   ├── hotels/
│   ├── events/
│   ├── education/
│   └── commerce/
│
├── payments/
├── notifications/
├── analytics/
├── admin/
└── main.py

## Modules principaux

### Identity

Gère :
- inscription
- connexion
- JWT
- profils utilisateurs
- rôles
- permissions

### Companies

Gère toutes les organisations :
- compagnies de transport
- hôtels
- organisateurs d’événements
- écoles
- commerces

### Transport

Gère :
- bus
- routes
- voyages
- sièges
- réservations
- tickets QR

### Hotels

Gère :
- hôtels
- chambres
- disponibilités
- réservations

### Events

Gère :
- événements
- billets
- places
- organisateurs

### Education

Futur module :
- écoles
- élèves
- enseignants
- classes
- notes
- paiements scolaires

### Commerce

Futur module :
- magasins
- produits
- stocks
- factures
- ventes
- clients

## Modules partagés

Ces modules seront utilisés par toute la plateforme :

- Users
- Companies
- Payments
- Notifications
- Countries
- Cities
- Currencies
- Analytics

## Principe technique

Chaque module doit suivre cette structure :

module/
├── schemas.py
├── repository.py
├── service.py
└── router.py

## Règle importante

Le projet doit rester une seule plateforme, mais chaque domaine métier doit être indépendant.

Guinea Go ne sera pas seulement une application de transport.
Ce sera une plateforme multi-services évolutive.