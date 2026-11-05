# MedLink DZ

MVP produit de coordination du parcours de soins en Algérie, disponible en français, arabe et anglais. L'objectif est un lancement public progressif avec des professionnels réellement vérifiés et des utilisateurs réels, après validation des prérequis réglementaires et opérationnels.

## Stack
- Next.js 15.5.28, React 19, TypeScript, Tailwind CSS 4
- Supabase Auth, PostgreSQL, Row Level Security et Realtime
- Vercel

## Développement local
```bash
npm install
npm run dev
```

Copier `.env.example` vers `.env.local` et renseigner :
- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`

Ne jamais exposer une clé `service_role` ou `sb_secret_*` dans le navigateur ou une variable `NEXT_PUBLIC_*`.

## Fonctionnalités du MVP
- Comptes patients et professionnels via Supabase Auth
- Annuaire public limité aux professionnels approuvés par MedLink
- Demandes de rendez-vous, décisions du professionnel et notifications internes
- Messagerie privée patient-professionnel en temps réel
- Demandes de visites à domicile avec traitement par le professionnel choisi
- Suivis post-consultation créés et publiés par le professionnel
- Administration protégée pour l'examen des candidatures, les décisions de vérification et le journal d'audit
- Interface responsive, français / arabe RTL / anglais

## Sécurité
- Row Level Security sur les tables exposées
- Rôles non modifiables par les utilisateurs depuis le client
- Permissions SQL limitées par colonne et transitions d'état validées en base
- Conversations et profils patients visibles uniquement par leurs participants et professionnels ayant une relation active
- Documents de vérification à stocker dans un bucket privé, jamais dans un bucket public

## Périmètre exclu du premier lancement
- Encaissement des consultations, paiements en ligne et remboursements automatiques
- Notifications SMS, WhatsApp ou appels téléphoniques
- Diagnostic, prescription ou décision clinique par IA
- Planification automatique avancée et intégrations hospitalières
- Gestion multi-clinique avancée et abonnements payants

Ces fonctions ne doivent pas être présentées comme disponibles tant que leur implémentation et leurs tests ne sont pas achevés.

## Conditions préalables au lancement public
- Validation par un conseil juridique local des obligations applicables, notamment la loi 18-07 modifiée et les exigences ANPDP
- Validation du cadre applicable aux services de santé et à la publicité des professionnels
- Procédure documentée de vérification des diplômes, cartes et autorisations professionnelles, avec renouvellement et suspension
- Politique de confidentialité, consentement, conservation, suppression et gestion des incidents
- Contrat et responsabilités des professionnels et cliniques partenaires
- Tests de sécurité indépendants, tests de charge, sauvegardes et procédure de restauration
- Configuration des domaines, e-mails transactionnels, surveillance et support utilisateur

Le statut « Vérifié par MedLink » décrit uniquement le contrôle interne de la plateforme. Il ne signifie pas agrément ministériel ni autorisation de l'État.
