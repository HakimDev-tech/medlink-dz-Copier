# MedLink DZ

Prototype universitaire trilingue (français, arabe, anglais) d'une plateforme de coordination du parcours de soin en Algérie.

## Stack
Next.js 15, React 19, TypeScript, Tailwind CSS 4, Lucide.

## Démarrer
```bash
pnpm install
pnpm dev
```

## Parcours
- /fr, /ar, /en : landing trilingue et RTL arabe
- /[locale]/doctors : annuaire de démonstration
- /[locale]/professional : tableau de bord professionnel fictif
- /[locale]/register et /professional/register : parcours d'inscription de démonstration
- /[locale]/admin/verifications : file de validation simulée
- /[locale]/login : écran de connexion non connecté

## Limites de sécurité et de conformité
Ce dépôt est un prototype d'interface. Aucun compte réel, dossier médical, paiement, rendez-vous, notification externe ou agrément officiel n'est traité. Profils et statistiques fictifs. Ne pas déposer de données personnelles, pièces d'identité ou données de santé. Avant toute utilisation réelle, connecter une authentification sécurisée, une base de données, un stockage privé, des contrôles d'accès côté serveur, des journaux d'audit et faire valider les obligations juridiques algériennes et la procédure de vérification officielle.