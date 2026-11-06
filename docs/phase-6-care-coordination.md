# Phase 6 — Consultation, suivi et notifications

## 1. Parcours nominal

```text
Rendez-vous confirmé
  → Consultation réalisée
  → Rendez-vous marqué « terminé »
  → Compte rendu créé en brouillon
  → Résumé patient + consignes + notes privées séparées
  → Validation explicite et publication du compte rendu
  → Programme de suivi créé sur ce rendez-vous terminé
  → Rappels datés ajoutés au brouillon
  → Relecture et publication par le professionnel
  → Programme et prochains rappels visibles par le patient
  → Notifications internes distribuées à échéance
  → Assistant limité au programme publié
  → Escalade vers le professionnel si la demande sort du cadre
```

## 2. Compte rendu de consultation

Route professionnelle : `/[locale]/professional/consultation/[appointmentId]`.

- L'accès est réservé au professionnel affecté au rendez-vous.
- Le rendez-vous doit être à l'état `completed`.
- Une ligne `consultation_records` unique est liée au rendez-vous, au patient et au professionnel.
- Le professionnel peut enregistrer un brouillon puis le corriger.
- La publication est explicite et irréversible dans l'interface.
- Le patient ne lit que les lignes `published`.
- Les notes privées sont stockées dans `consultation_private_notes`, avec une politique et un contrôle d'intégrité séparés.
- Le compte rendu publié et ses participants sont immuables au niveau SQL.

Les champs destinés au patient ne doivent contenir que le résumé et les consignes que le professionnel souhaite lui communiquer. Les notes privées ne sont jamais injectées dans l'assistant.

## 3. Programme de suivi

Composant : `src/components/follow-up-plan-form.tsx`.

- Un programme doit référencer le rendez-vous terminé correspondant, le patient correspondant et le professionnel affecté.
- Le brouillon est enregistrable, modifiable et récupérable après rechargement de l'espace professionnel.
- Les rappels du brouillon peuvent être ajoutés et supprimés avant publication.
- La publication exige au moins un rappel futur.
- Les contenus d'un programme publié ne peuvent pas être modifiés silencieusement. Une nouvelle version clinique doit être créée explicitement.
- Les événements publiés peuvent être ajustés sous contrôle SQL ; chaque changement incrémente `schedule_version`, synchronise la file et informe le patient.
- Une date de rappel déjà distribuée ou en cours de distribution ne peut pas être déplacée.

## 4. Assistant patient — pseudo-RAG

Entrée : `POST /api/agent/follow-up`.

Ordre de traitement :
1. Valider le corps de requête et la session.
2. Vérifier que l'utilisateur est le patient propriétaire du programme demandé.
3. Vérifier que le programme est publié.
4. Appliquer une limite de 20 requêtes par patient sur 10 minutes.
5. Récupérer uniquement les consignes du programme et ses rappels futurs.
6. Détecter les urgences potentielles et les demandes cliniques interdites.
7. Pour les demandes de clarification, découper les consignes en passages et faire une recherche lexicale conservatrice.
8. Répondre uniquement avec les passages retrouvés ou les rappels enregistrés ; ne pas compléter les informations absentes.
9. Journaliser l'intention, le résultat et les indicateurs de sécurité, sans conserver le texte brut de la question.
10. Créer une escalade et notifier le professionnel en cas de transfert humain.

Le mécanisme actuel est un pseudo-RAG lexical déterministe. Il ne fait pas appel à un LLM, n'effectue aucun diagnostic, ne recommande aucun traitement, ne modifie aucun programme et ne remplace pas un professionnel. Un futur fournisseur de modèle devra rester derrière cette frontière de sécurité et ne recevoir que les passages approuvés strictement nécessaires.

## 5. Notifications et distribution

Tables principales :
- `notification_schedules` : file des rappels, clé d'idempotence, tentatives, version et statut.
- `notification_logs` : journal technique des tentatives, non exposé aux rôles clients.
- `notifications` : boîte de réception interne par utilisateur.
- `follow_up_events` : source des dates, intitulés et consignes de rappel.

Le job PostgreSQL `medlink-notification-dispatch` s'exécute chaque minute. Il :
- verrouille les lignes échues avec `FOR UPDATE SKIP LOCKED` ;
- limite chaque lot à 50 lignes ;
- crée une notification interne avec `source_job_id` unique ;
- marque le job comme envoyé ou planifie une nouvelle tentative avec délai exponentiel ;
- conserve les erreurs sous forme de code générique et écrit un journal de traitement.

Les notifications sont diffusées à l'interface par Realtime. Le statut lu/non lu est enregistré en base. Les notifications couvrent les demandes et changements de rendez-vous, les visites à domicile, les comptes rendus publiés, les programmes et rappels de suivi ainsi que les escalades de l'assistant.

**Canal effectivement implémenté : notification interne dans l'application.** SMS, WhatsApp, e-mail et appels restent hors périmètre.

## 6. Contrôles à effectuer avant lancement

- Tester avec des comptes synthétiques patient et professionnel, sans données médicales réelles.
- Vérifier le rejet d'un rendez-vous non terminé, d'un programme non publié et d'un programme appartenant à un autre patient.
- Vérifier que les notes privées ne sont jamais visibles depuis une session patient.
- Vérifier qu'un compte rendu publié ne peut plus être modifié.
- Vérifier que les rappels ne sont pas distribués avant leur échéance et qu'une relance ne crée pas de doublon.
- Vérifier qu'un rappel supprimé ou un programme clôturé ne produit plus de notification.
- Vérifier les trois langues, le RTL arabe, les fuseaux horaires et le passage à l'heure d'été/hiver.
- Vérifier l'escalade d'une demande clinique, d'une question non couverte et d'un signal urgent.
- Vérifier la reprise du job après une erreur et l'absence de double distribution.
- Réaliser une revue juridique et sécurité avant toute donnée patient réelle.

Aucune de ces vérifications ne doit être considérée comme un test de bout en bout tant qu'elle n'a pas été exécutée sur des comptes de test dédiés.
