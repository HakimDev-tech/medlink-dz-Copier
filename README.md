# MedLink DZ

MVP produit de coordination du parcours de soins en Algérie, disponible en français, arabe et anglais. Le lancement public doit rester progressif, avec des professionnels réellement vérifiés et après validation des prérequis réglementaires et opérationnels.

## Stack
- Next.js 15.5.28, React 19, TypeScript, Tailwind CSS 4
- Supabase Auth, PostgreSQL, Row Level Security, Realtime et pg_cron
- Vercel

## Développement local
```bash
npm install
npm run dev
```

Copier `.env.example` vers `.env.local` et renseigner :
- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`

Pour synchroniser un environnement de base de données avec les migrations versionnées du dépôt :
```bash
supabase link --project-ref cftaxeibbvjryrufahlo
supabase db push
```

Ne jamais exposer une clé `service_role` ou `sb_secret_*` dans le navigateur ou une variable `NEXT_PUBLIC_*`.

## Parcours de consultation et suivi — Phase 6

1. Le rendez-vous doit être marqué comme terminé par le professionnel.
2. Le professionnel ouvre le parcours de consultation associé à ce rendez-vous.
3. Il rédige un résumé destiné au patient, les consignes qui lui sont remises et, séparément, ses notes privées.
4. Le brouillon peut être corrigé. La publication demande une confirmation explicite.
5. Une fois publié, le compte rendu est accessible au patient et devient immuable. Les notes privées restent réservées au professionnel.
6. Le professionnel crée un programme de suivi lié au rendez-vous terminé, ajoute ou retire les rappels, peut corriger le brouillon, puis le publie.
7. Le patient voit le programme, ses prochains rappels, les notifications et peut poser des questions à l'assistant.

Les contrôles de statut, l'association rendez-vous/patient/professionnel et les règles d'accès sont également appliqués côté base de données. L'interface seule n'est jamais considérée comme une frontière de sécurité.

## Assistant de suivi — pseudo-RAG

Le point d'entrée applicatif est `POST /api/agent/follow-up`. L'assistant :
- n'accepte qu'un patient authentifié qui possède le programme publié demandé ;
- récupère uniquement les consignes et les rappels futurs de ce programme ;
- effectue une recherche lexicale conservatrice dans les consignes approuvées et ne restitue que les passages correspondants ;
- répond avec les rappels enregistrés lorsqu'une question porte sur les dates ;
- refuse les demandes de diagnostic, d'interprétation de symptômes, de médicament, de dose ou de traitement ;
- signale les demandes hors périmètre et les signaux d'urgence au professionnel concerné ;
- journalise l'intention, le résultat et les indicateurs de sécurité, sans conserver le texte brut de la question ;\n- applique une limite de 20 requêtes par patient sur une fenêtre glissante de 10 minutes.

Il s'agit volontairement d'un **pseudo-RAG déterministe**, pas d'un LLM ni d'un moteur vectoriel. Aucun fournisseur IA externe ni clé API de modèle n'est nécessaire pour ce socle. Il ne prend aucune décision clinique, ne modifie pas un programme et ne remplace pas le professionnel.

## Notifications synchronisées

- Les demandes de rendez-vous et de visite à domicile, les changements de statut, les annulations patient, les publications de compte rendu et de suivi ainsi que les transferts vers le professionnel créent des notifications internes.
- Les rappels sont créés à partir des événements du programme validé.
- La publication d'un programme alimente automatiquement la file `notification_schedules`.
- Un job PostgreSQL `pg_cron` s'exécute chaque minute et distribue les notifications internes arrivées à échéance.
- Le traitement utilise des verrous `SKIP LOCKED`, une clé d'idempotence, des tentatives bornées, un délai exponentiel et un journal technique.
- Les notifications sont synchronisées dans l'interface via Realtime et peuvent être marquées comme lues.
- Les modifications ou suppressions de rappels après publication mettent à jour la version du programme et la file de distribution.

**Périmètre actuel : notifications internes à l'application uniquement.** Aucun SMS, WhatsApp, e-mail transactionnel ou appel n'est envoyé par ce mécanisme.

## Fonctionnalités du MVP
- Comptes patients et professionnels
- Annuaire public limité aux professionnels approuvés par MedLink
- Demandes de rendez-vous, décisions du professionnel et notifications internes
- Parcours de consultation avec brouillon, publication et notes privées séparées
- Programmes de suivi post-consultation et rappels synchronisés
- Assistant de clarification limité au programme validé et transfert au professionnel
- Messagerie privée patient-professionnel en temps réel
- Demandes de visites à domicile
- Dépôt sécurisé de justificatifs professionnels, examen documentaire par les administrateurs et contrôle de vérification en base
- Administration protégée et journal d'audit
- Interface responsive, français / arabe RTL / anglais

## Sécurité
- Row Level Security sur les tables exposées
- Rôles non modifiables par les utilisateurs depuis le client
- Permissions SQL limitées par colonne et transitions d'état validées en base
- Les notes privées de consultation ne sont pas accessibles au patient
- Les comptes rendus publiés sont immuables
- Les programmes non publiés ne sont pas accessibles au patient
- Les journaux de distribution et les fonctions internes restent inaccessibles aux rôles clients
- Les documents professionnels sont stockés dans un bucket privé

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
