# MedLink DZ

Prototype universitaire trilingue (français, arabe, anglais) de coordination du parcours de soin en Algérie.

## Stack
- Next.js 15.5.28 (correctif de sécurité), React 19, TypeScript, Tailwind CSS 4
- Supabase Auth, PostgreSQL et RLS
- Vercel

## Démarrer
```bash
npm install
npm run dev
```

Copier `.env.example` vers `.env.local`, puis renseigner :
- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`

N'ajoutez jamais de clé `service_role` ou `sb_secret_*` dans une variable `NEXT_PUBLIC_*` ni dans le navigateur.

## Parcours implémentés
- `/[locale]` : landing page trilingue
- `/[locale]/doctors` : annuaire alimenté par Supabase, profils vérifiés uniquement
- `/[locale]/register`, `/[locale]/login` : inscription patient et connexion Supabase Auth
- `/[locale]/professional/register` : dépôt de candidature professionnelle (statut initial pending)
- `/[locale]/professional` : rendez-vous du professionnel, confirmation/refus, création d'un suivi brouillon puis publication
- `/[locale]/patient` : rendez-vous et suivis publiés
- `/auth/callback` : échange PKCE du code d'authentification
- `/[locale]/admin/verifications` : interface de démonstration uniquement (pas encore reliée à un rôle administrateur réel)

## Base de données
Migrations dans `supabase/migrations`. Schéma appliqué au projet Supabase `medlink-DZ` :
- profils, médecins, cliniques et membres
- rendez-vous, plans de suivi et événements
- visites à domicile, conversations et messages
- notifications, demandes de remboursement, journaux d'audit
- RLS activée sur toutes les tables exposées
- le rôle médecin est attribué par trigger après dépôt d'une candidature, sans accepter de rôle fourni par l'utilisateur
- les décisions de vérification ne sont pas accessibles aux utilisateurs depuis le client

## Limites importantes
Ce dépôt reste un MVP universitaire, pas un logiciel médical certifié. Les profils sont masqués tant que leur vérification n'est pas approuvée. Le statut « vérifié par la plateforme » ne signifie pas agrément ministériel ou autorisation officielle.

Ne pas utiliser de vraies données de santé, pièces d'identité, prescriptions ou informations de patients dans la démo. Les consignes publiées doivent être fictives. Les paiements, remboursements, SMS, appels, moteur de notifications planifiées, IA clinique, multi-clinique avancé et workflow administrateur complet ne sont pas encore implémentés.

Avant toute mise en production : revue juridique algérienne, analyse des obligations de la loi 18-07 telle que modifiée, contrôle ANPDP, audit de sécurité, politique de conservation et hébergement, tests d'intrusion et procédure de vérification des professionnels.
