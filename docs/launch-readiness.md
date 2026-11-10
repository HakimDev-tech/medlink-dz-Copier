# MedLink DZ — lancement, qualité et conformité

**État du document :** plan de contrôle et état de préparation, pas une certification ni un avis juridique.

## 1. Traductions FR / EN / AR

Les catalogues centraux `src/lib/i18n.ts` contiennent actuellement 155 clés par langue. Les objets `copy` et `portalCopy` de `src/lib/data.ts`, le formulaire d'authentification et les composants professionnels ont des catalogues trilingues.

Le test `tests/locale-parity.test.mjs` compare les clés des catalogues ciblés et détecte les clés manquantes. Il ne peut pas prouver la qualité linguistique, détecter tous les textes codés en dur dans les pages, ni contrôler le rendu SVG/Canvas ou les textes issus des fournisseurs.

**Recette de traduction obligatoire :**
- parcourir toutes les routes publiques, patient, médecin, clinique et administration en FR/EN/AR ;
- inventorier les textes visibles codés en dur, messages d'erreur, validations, états vides, e-mails, notifications et métadonnées ;
- vérifier les formats de dates, nombres et montants ;
- contrôler RTL réel en arabe : alignement, icônes directionnelles, tableaux, formulaires, menus et composants tiers ;
- faire relire l'arabe et les textes médicaux par un locuteur compétent du domaine ;
- contrôler le texte intégré aux SVG/images : une traduction HTML ne traduit pas les images.

**Critère de sortie :** zéro texte fonctionnel non traduit dans chaque parcours pris en charge ; aucune clé manquante ; validation humaine des libellés médicaux et juridiques.

## 2. Tests automatisés

### État actuel
- Tests Node du moteur de sécurité déterministe de l'assistant : présents.
- Test de parité des catalogues de traduction : ajouté.
- Build de production et lint : exécutés par CI.
- Aucun framework de tests unitaires React, d'intégration API/DB ou E2E navigateur n'est encore configuré dans le dépôt.
- Les tests de l'assistant ne constituent pas une validation clinique.

### Pyramide à compléter
1. **Unitaires :** validation de schémas, transitions d'états, calcul de créneaux, règles d'entitlements, gestion de fuseaux horaires, adaptateurs de notification et assistant.
2. **Intégration :** routes API avec Supabase local/staging, transactions, contraintes, cron/queue, provider mocks et erreurs réseau.
3. **RLS/autorisation :** exécuter les scénarios avec des JWT de comptes distincts patient, médecin A, médecin B, gestionnaire, admin et anon.
4. **E2E :** Playwright sur Chromium et WebKit, viewport mobile/desktop, FR/EN/AR, parcours de réservation, consultation, publication de suivi, escalade, abonnement et administration.
5. **Régression :** conserver les tests reproductibles des bugs corrigés et exécuter l'ensemble sur chaque pull request.

Ne pas utiliser de vraies données médicales. Créer des comptes et dossiers entièrement synthétiques dans un projet de staging isolé.

## 3. Matrice minimale de tests RLS

| Ressource | Patient A | Patient B | Médecin lié | Médecin non lié | Admin |
|---|---|---|---|---|---|
| Profil patient | Lecture propre | Refus | Lecture strictement nécessaire | Refus | Accès selon rôle |
| Consultation publiée | Propre | Refus | Dossier lié | Refus | Selon rôle |
| Notes privées | Refus | Refus | Médecin auteur | Refus | Accès exceptionnel audité si nécessaire |
| Programme publié | Propre | Refus | Médecin auteur | Refus | Selon politique |
| Programme brouillon | Refus | Refus | Médecin auteur | Refus | Selon politique |
| Documents professionnels | Refus | Refus | Propre | Refus | Revue autorisée |
| Abonnements/factures | Refus | Refus | Propres | Refus | Finance/admin |
| Notes de remboursement | Refus | Refus | Refus | Refus | Admin autorisé |

Tester également les attaques BOLA/IDOR : substituer les UUID dans chaque route, RPC, requête Storage, téléchargement et mutation. Un contrôle d'interface ne constitue jamais une autorisation.

## 4. Charge, disponibilité et capacité

Avant le lancement :
- établir les objectifs SLO et le profil de charge attendu ;
- tester les parcours de connexion, recherche, lecture de dossier, réservation et notifications avec k6 ou outil équivalent ;
- tester les pics de réservation concurrente et la contention sur un médecin ;
- mesurer p50/p95/p99, taux d'erreur, saturation DB, connexions, latence Edge et consommation ;
- définir seuils d'alerte, limites de débit, quotas et plan de montée en charge ;
- tester la dégradation d'un fournisseur IA ou SMS sans perte des notifications internes.

Aucun résultat de test de charge n'est actuellement certifié. Ne pas annoncer une capacité maximale avant mesure sur l'infrastructure cible.

## 5. Sauvegarde et restauration

- vérifier le plan Supabase réellement souscrit, la rétention et la disponibilité PITR ;
- documenter RPO/RTO acceptables avec le responsable métier ;
- vérifier la sauvegarde des objets Storage séparément de PostgreSQL ;
- sauvegarder les secrets et configurations de manière chiffrée et contrôlée, jamais dans Git ;
- effectuer un exercice de restauration dans un projet isolé ;
- contrôler intégrité référentielle, nombre d'enregistrements, pièces jointes, Auth, fonctions, cron et politiques RLS après restauration ;
- consigner date, opérateur, durée, résultats et écarts.

**Une sauvegarde configurée n'est pas une restauration testée.** Aucun exercice complet de restauration n'est attesté par ce dépôt.

## 6. Surveillance et journalisation

Surveiller au minimum :
- erreurs serveur/API et taux 4xx/5xx ;
- latence et disponibilité des routes ;
- échecs d'authentification et anomalies d'accès ;
- erreurs PostgreSQL, saturation et connexions ;
- échecs de notifications, retries et jobs bloqués ;
- erreurs fournisseur IA, latence et limites ;
- escalades de l'assistant et actions administratives ;
- changements de rôles, vérification des médecins, accès administrateur et changements de facturation.

Les journaux doivent être structurés, horodatés, corrélés par identifiant de requête et expurgés des données de santé, secrets, tokens, mots de passe et contenus de conversation. Définir accès, rétention, rotation et procédure de réponse aux incidents. Ne pas journaliser les prompts médicaux ou réponses complètes par défaut.

Le projet dispose déjà de journaux techniques Supabase et de journaux de distribution. Cela ne prouve pas qu'une solution d'alerting opérationnel, un astreinte ou une procédure incident sont configurés.

## 7. Données de santé et cadre juridique algérien

Textes à examiner avec un avocat algérien :
- loi n° 18-07 du 10 juin 2018 relative à la protection des personnes physiques dans le traitement des données à caractère personnel ;
- loi n° 25-11 du 24 juillet 2025 qui modifie et complète la loi 18-07 ;
- loi n° 18-11 relative à la santé et textes réglementaires applicables aux professionnels et établissements ;
- règles professionnelles, secret médical, responsabilité du médecin, conservation du dossier et obligations contractuelles.

La loi 25-11 ajoute notamment :\n- les articles 41 bis et 41 bis 1 relatifs au délégué à la protection des données ;\n- les articles 41 bis 2 et 41 bis 3 relatifs au registre des activités de traitement et au carnet automatisé des opérations (collecte, consultation, utilisation, communication, conservation, effacement, etc.) ;\n- l'article 45 bis 6 relatif à l'étude d'impact préalable lorsqu'un traitement est susceptible d'engendrer des risques élevés ;\n- les articles 45 bis 7 à 45 bis 10 relatifs aux mesures de sécurité, à la documentation des violations et à leur notification à l'ANPDP au plus tard cinq jours après leur découverte, avec information des personnes concernées si le risque est élevé, sous les conditions du texte.\n\nCes dispositions sont celles du texte modificatif publié au Journal officiel n° 48 du 24 juillet 2025. Les obligations précises, les exemptions, les traitements de suivi médical individuel et les modalités d'application à MedLink doivent être qualifiés juridiquement. Ne pas se contenter d'une lecture isolée de la loi 18-07 dans sa version initiale.

### Dossier juridique et privacy à préparer
- cartographie des traitements et des flux de données ;
- identification des responsables de traitement, sous-traitants et destinataires ;
- finalités, bases légales, consentements et gestion du retrait ;
- registre des traitements et analyse des risques ;
- désignation/évaluation de l'obligation de désigner un DPO ;
- contrats de sous-traitance et engagements de confidentialité ;
- transferts internationaux, localisation, accès support et sous-traitants ultérieurs ;
- droits d'accès, rectification, effacement/opposition lorsque applicables ;
- durée de conservation, archivage, suppression et gel légal ;
- procédure de violation de données et notification ;
- politique de confidentialité, CGU, contrats médecins/cliniques et clauses de responsabilité ;
- analyse spécifique des données de santé, des mineurs et des pièces justificatives professionnelles.

**Hébergement :** ne pas affirmer que la loi impose automatiquement l'hébergement de toutes les données en Algérie sans avis juridique portant sur les articles applicables et les transferts internationaux. Il faut examiner le lieu d'hébergement, les accès distants, les sauvegardes, les sous-traitants et les mécanismes de transfert.

**IA :** aucun dossier patient réel ne doit être transmis à un fournisseur de modèle avant validation de la base légale, des rôles, du contrat de traitement, de la localisation/transfert, de la rétention et de la politique d'entraînement du fournisseur. Les clés restent côté serveur. La validation du médecin reste obligatoire et l'agent ne doit pas diagnostiquer, prescrire ou modifier un traitement.

## 8. Décision de lancement

Le lancement public est **NO-GO** tant que les points bloquants suivants ne sont pas levés :
- revue juridique algérienne et conformité données de santé ;
- audit de sécurité indépendant et campagne RLS négative ;
- tests E2E des parcours critiques ;
- test de charge avec objectifs chiffrés ;
- sauvegarde et restauration réellement éprouvées ;
- alertes, réponse aux incidents et support opérationnel ;
- revue linguistique humaine FR/AR/EN ;
- contrats et vérification professionnelle opérationnels.

La compilation réussie et les tests unitaires existants ne suffisent pas à qualifier un produit de prêt pour un lancement public.
