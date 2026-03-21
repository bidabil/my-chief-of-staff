# Chief of Staff — Assistant IA Personnel

> **Ce que fait ce projet en une phrase :**
> Tu envoies un message à ton bot Telegram, il te répond via DeepSeek R1 (IA), se souvient de vos conversations, et t'envoie automatiquement un briefing tous les matins à 7h00.

---

## Table des matières

1. [Comment ça marche](#comment-ça-marche)
2. [Ce dont tu as besoin avant de commencer](#ce-dont-tu-as-besoin-avant-de-commencer)
3. [Démarrage en local (sur ton ordinateur)](#démarrage-en-local-sur-ton-ordinateur)
4. [Déploiement sur un serveur](#déploiement-sur-un-serveur)
5. [Configurer GitHub pour le déploiement automatique](#configurer-github-pour-le-déploiement-automatique)
6. [Faire une mise à jour (release)](#faire-une-mise-à-jour-release)
7. [Comment utiliser l'assistant au quotidien](#comment-utiliser-lassistant-au-quotidien)
8. [Comprendre la structure du projet](#comprendre-la-structure-du-projet)
9. [Résolution de problèmes](#résolution-de-problèmes)
10. [Référence des variables d'environnement](#référence-des-variables-denvironnement)

---

## Comment ça marche

```
Toi (Telegram)
      │
      │  Tu envoies un message
      ▼
  Bot Telegram
      │
      ▼
   n8n (cerveau de l'automatisation)
      │
      ├──► PostgreSQL  (se souvient de tes conversations passées)
      │
      ▼
  1min-Gateway (traducteur vers DeepSeek)
      │
      ▼
  DeepSeek R1 (l'IA qui génère la réponse)
      │
      ▼
  n8n renvoie la réponse à ton Telegram
```

**Les services qui tournent en arrière-plan :**

| Service | Rôle | Port |
|---|---|---|
| **n8n** | Orchestre tout (le "chef d'orchestre") | 5678 |
| **PostgreSQL + pgvector** | Stocke les données et la mémoire de l'IA | 5432 |
| **1min-Gateway** | Traduit les requêtes n8n vers DeepSeek | 5001 |
| **Caddy** | Gère le HTTPS (certificat SSL automatique) | 80/443 |
| **Backup** | Sauvegarde PostgreSQL tous les jours à minuit | — |

---

## Ce dont tu as besoin avant de commencer

### 1. Docker Desktop

Docker permet de lancer tous les services sans rien installer manuellement.

- Télécharge et installe **Docker Desktop** : https://www.docker.com/products/docker-desktop/
- Vérifie que ça fonctionne :
  ```bash
  docker --version
  # Doit afficher : Docker version 24.x.x ou supérieur
  ```

### 2. Un compte 1min.ai et sa clé API

1min.ai est le service qui donne accès à DeepSeek R1.

1. Créer un compte sur https://1min.ai
2. Aller dans **Settings → API Keys → Create new key**
3. Copier la clé (elle ressemble à `sk-...`) — tu en auras besoin plus tard

### 3. Un bot Telegram

Un bot Telegram, c'est un "contact" dans Telegram qui répond automatiquement.

**Créer le bot :**
1. Ouvre Telegram et cherche **@BotFather**
2. Envoie la commande `/newbot`
3. Donne un nom à ton bot (ex : `Mon Chief of Staff`)
4. Donne un username qui se termine par `bot` (ex : `monchiefofstaff_bot`)
5. BotFather te donne un **token** qui ressemble à `7123456789:AAFxxx...` — copie-le

**Trouver ton Chat ID (pour le briefing matinal) :**
1. Dans Telegram, cherche **@userinfobot**
2. Envoie `/start`
3. Il te répond avec ton **Id** — c'est un nombre comme `123456789` — copie-le

### 4. Git

```bash
git --version
# Si non installé : https://git-scm.com/downloads
```

---

## Démarrage en local (sur ton ordinateur)

Le mode local sert à **tester et développer** sans toucher au serveur de production.

### Étape 1 — Cloner le projet

```bash
git clone <url-du-repo>
cd chief-of-staff
```

### Étape 2 — Créer ton fichier de configuration

```bash
cp .env.dev .env
```

Ouvre `.env` avec ton éditeur et remplace ces 3 valeurs :

```env
ONE_MIN_AI_API_KEY=mets-ta-vraie-clé-1min-ai-ici
TELEGRAM_BOT_TOKEN=mets-ton-vrai-token-bot-ici
TELEGRAM_CHAT_ID=mets-ton-vrai-chat-id-ici
```

> ⚠️ **Ne touche pas aux autres valeurs.** Les valeurs par défaut (mots de passe, clés de chiffrement) fonctionnent tel quel en local.

### Étape 3 — Lancer la stack

```bash
make dev
```

Tu devrais voir :

```
Stack démarré :
  n8n      → http://localhost:5678
  gateway  → http://localhost:5001
  postgres → localhost:5432
```

### Étape 4 — Vérifier que tout fonctionne

1. Ouvre http://localhost:5678 dans ton navigateur
2. Crée ton compte administrateur n8n (première fois uniquement)
3. Tu devrais voir le workflow **Morning Briefing** déjà importé et actif
4. Envoie un message à ton bot Telegram → il devrait répondre

### Commandes utiles en local

```bash
make dev        # Démarrer la stack
make dev-down   # Arrêter la stack
make dev-logs   # Voir les logs en temps réel (Ctrl+C pour quitter)
make dev-reset  # Tout effacer et repartir de zéro (supprime les données)
```

---

## Déploiement sur un serveur

Cette section explique comment déployer sur un **vrai serveur** (VPS) accessible depuis internet.

Tu auras besoin de **deux serveurs** :
- **Staging** : pour tester avant de mettre en production
- **Production** : le vrai serveur que tu utilises au quotidien

> 💡 **Recommandation VPS** : DigitalOcean, Hetzner, ou OVH. Configuration minimale : 2 vCPU / 2 Go RAM / Ubuntu 22.04.

### Étape 1 — Préparer chaque serveur

Se connecter au serveur en SSH et exécuter :

```bash
# Installer Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# Déconnecte-toi et reconnecte-toi pour appliquer le groupe
exit
```

Reconnecte-toi puis :

```bash
# Cloner le repo dans /opt/chief-of-staff
sudo git clone <url-du-repo> /opt/chief-of-staff
sudo chown -R $USER:$USER /opt/chief-of-staff
cd /opt/chief-of-staff

# Créer le fichier .env
cp .env.example .env
nano .env
```

### Étape 2 — Remplir le `.env` sur le serveur

Dans le fichier `.env`, remplir **toutes** les valeurs marquées `your-*` :

```env
# Clé 1min.ai
ONE_MIN_AI_API_KEY=ta-vraie-clé

# Telegram
TELEGRAM_BOT_TOKEN=ton-vrai-token
TELEGRAM_CHAT_ID=ton-vrai-chat-id

# PostgreSQL — choisir un mot de passe solide (min 16 caractères)
POSTGRES_USER=chief
POSTGRES_PASSWORD=un-mot-de-passe-très-solide-ici
POSTGRES_DB=chief_db

# Clés n8n — générer avec : openssl rand -hex 32
N8N_ENCRYPTION_KEY=coller-le-résultat-de-openssl-ici
N8N_USER_MANAGEMENT_JWT_SECRET=coller-un-autre-résultat-ici

# URL publique de ton serveur
WEBHOOK_URL=https://ton-domaine.com

# HTTPS avec Caddy
COMPOSE_PROFILES=tls
DOMAIN=ton-domaine.com
ACME_EMAIL=ton-email@exemple.com
```

**Pour générer les clés n8n :**
```bash
openssl rand -hex 32   # Exécuter deux fois — une fois pour chaque clé
```

### Étape 3 — Pointer ton domaine vers le serveur

Dans ton registrar DNS (OVH, Namecheap, Cloudflare...) :

| Type | Nom | Valeur |
|---|---|---|
| `A` | `@` | IP de ton serveur de production |
| `A` | `staging` | IP de ton serveur staging |

> ⏳ La propagation DNS peut prendre jusqu'à 24h, mais en général c'est quelques minutes.

### Étape 4 — Ouvrir les ports sur le serveur

```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 22/tcp
sudo ufw enable
```

### Étape 5 — Configurer les clés SSH pour GitHub Actions

GitHub Actions doit pouvoir se connecter à tes serveurs automatiquement.

**Sur ta machine locale**, générer une paire de clés SSH dédiée :

```bash
# Pour le staging
ssh-keygen -t ed25519 -C "github-actions-staging" -f ~/.ssh/github_actions_staging
# Appuie sur Entrée (pas de passphrase)

# Pour la production
ssh-keygen -t ed25519 -C "github-actions-production" -f ~/.ssh/github_actions_production
```

**Copier la clé publique sur chaque serveur :**

```bash
# Staging
ssh-copy-id -i ~/.ssh/github_actions_staging.pub user@staging.ton-domaine.com

# Production
ssh-copy-id -i ~/.ssh/github_actions_production.pub user@ton-domaine.com
```

**Afficher les clés privées** (tu en auras besoin à l'étape suivante) :

```bash
cat ~/.ssh/github_actions_staging      # Copier tout le contenu (clé staging)
cat ~/.ssh/github_actions_production   # Copier tout le contenu (clé production)
```

---

## Configurer GitHub pour le déploiement automatique

### Secrets (valeurs sensibles — jamais visibles après saisie)

GitHub → Settings → Secrets and variables → Actions → **New repository secret**

| Nom du secret | Valeur à mettre |
|---|---|
| `STAGING_USER` | Ton nom d'utilisateur sur le serveur staging (ex: `ubuntu`) |
| `STAGING_SSH_KEY` | Contenu complet de `~/.ssh/github_actions_staging` |
| `STAGING_PATH` | Chemin du repo sur staging (ex: `/opt/chief-of-staff`) |
| `PRODUCTION_USER` | Ton nom d'utilisateur sur le serveur de prod (ex: `ubuntu`) |
| `PRODUCTION_SSH_KEY` | Contenu complet de `~/.ssh/github_actions_production` |
| `PRODUCTION_PATH` | Chemin du repo en prod (ex: `/opt/chief-of-staff`) |
| `TELEGRAM_BOT_TOKEN` | Token de ton bot Telegram |
| `TELEGRAM_CHAT_ID` | Ton Chat ID Telegram |

### Variables (valeurs non-sensibles — visibles)

GitHub → Settings → Secrets and variables → Actions → onglet **Variables** → **New repository variable**

| Nom de la variable | Valeur à mettre |
|---|---|
| `STAGING_HOST` | Domaine ou IP de ton serveur staging (ex: `staging.ton-domaine.com`) |
| `PRODUCTION_HOST` | Domaine ou IP de ton serveur de prod (ex: `ton-domaine.com`) |

### Protection de la branche main

GitHub → Settings → Branches → **Add branch protection rule**

- Branch name pattern : `main`
- ✅ Cocher **Require status checks to pass before merging**
- Dans la liste des status checks, chercher et sélectionner **CI**
- ✅ Cocher **Require branches to be up to date before merging**
- Cliquer **Save changes**

> Avec cette règle, il est impossible de merger du code cassé sur `main`.

### Premier déploiement

```bash
git push origin main
```

Va dans GitHub → Actions et regarde les workflows s'exécuter en temps réel :
1. **CI** — vérifie que le code est propre (environ 2 min)
2. **CD Staging** — déploie sur staging et vérifie que tout fonctionne (environ 5 min)

Si le staging est vert ✅, tu peux déployer en production (voir section suivante).

---

## Faire une mise à jour (release)

Quand tu veux déployer une nouvelle version en **production**, le processus est toujours le même :

### Étape 1 — Créer la release

1. GitHub → Actions → **Release** → **Run workflow**
2. Choisir le type de changement :
   - `patch` — correction de bug (v1.0.0 → v1.0.1)
   - `minor` — nouvelle fonctionnalité (v1.0.0 → v1.1.0)
   - `major` — changement important (v1.0.0 → v2.0.0)
3. Cliquer **Run workflow**

Le workflow va :
- Calculer automatiquement le prochain numéro de version
- Créer un tag Git (`v1.0.1`)
- Créer une GitHub Release avec les notes de version
- T'envoyer une notification Telegram

### Étape 2 — Déployer en production

1. GitHub → Actions → **CD - Production** → **Run workflow**
2. Version : laisser `latest` (déploie automatiquement la dernière release)
3. Cliquer **Run workflow**

Le pipeline va :
1. Vérifier que staging est en bonne santé
2. Déployer sur production
3. Exécuter des smoke tests (vérifications que tout fonctionne)
4. En cas d'échec : **rollback automatique** vers la version précédente
5. T'envoyer une notification Telegram avec le résultat

---

## Comment utiliser l'assistant au quotidien

### Parler à l'assistant

Ouvre Telegram, envoie un message à ton bot. Il répond via DeepSeek R1.

L'assistant **se souvient des 10 derniers échanges** de la conversation — pas besoin de te répéter d'une session à l'autre.

### Briefing matinal automatique

Chaque matin à **7h00**, l'assistant t'envoie automatiquement un briefing sur Telegram (sans que tu aies besoin de rien faire).

---

## Comprendre la structure du projet

```
chief-of-staff/
│
├── docker-compose.yml          ← Définit tous les services (postgres, n8n, gateway, caddy, backup)
├── docker-compose.dev.yml      ← Modifications pour le dev local (expose postgres, désactive restart)
├── .env.example                ← Template à copier pour créer ton .env
├── .env.dev                    ← Variables pré-remplies pour le dev (remplacer les 3 clés réelles)
├── Makefile                    ← Raccourcis de commandes (make dev, make dev-reset...)
├── .editorconfig               ← Règles d'indentation pour l'éditeur (YAML=2 espaces, SQL=4)
├── .pre-commit-config.yaml     ← Vérifications automatiques avant chaque commit
│
├── caddy/
│   └── Caddyfile               ← Configuration du reverse proxy HTTPS
│
├── postgres/
│   └── init.sql                ← Activé au premier démarrage : installe pgvector + crée le schema memory
│
├── n8n/
│   └── demo-data/
│       ├── credentials/
│       │   ├── gateway.json    ← Connexion n8n → 1min-Gateway (lit ONE_MIN_AI_API_KEY depuis .env)
│       │   ├── telegram.json   ← Connexion n8n → Telegram Bot (lit TELEGRAM_BOT_TOKEN depuis .env)
│       │   └── postgres.json   ← Connexion n8n → PostgreSQL (pour la mémoire conversationnelle)
│       └── workflows/
│           └── morning-briefing.json   ← Le workflow principal (Telegram + briefing 7h00)
│
├── shared/                     ← Dossier partagé entre n8n et le serveur (fichiers échangés)
│
└── .github/
    ├── dependabot.yml                    ← Vérifie automatiquement les nouvelles versions des images Docker
    └── workflows/
        ├── ci.yml                        ← Vérifie le code à chaque push (lint, secrets, sécurité)
        ├── cd-staging.yml                ← Déploie sur staging à chaque push sur main
        ├── cd-production.yml             ← Déploie en production (déclenchement manuel)
        ├── release.yml                   ← Crée un tag vX.Y.Z et une GitHub Release
        └── dependabot-auto-merge.yml     ← Merge automatiquement les mises à jour mineures
```

---

## Résolution de problèmes

### Le bot Telegram ne répond pas

1. Vérifier que `TELEGRAM_BOT_TOKEN` est correct dans `.env`
2. Vérifier que le workflow **Morning Briefing** est **actif** dans n8n (bouton vert)
3. Regarder les logs : `make dev-logs` puis chercher les erreurs en rouge

### n8n ne démarre pas

```bash
make dev-logs
# Chercher les lignes contenant "ERROR"
```

Le problème le plus fréquent : des variables manquantes ou incorrectes dans `.env`.

### Le déploiement échoue sur GitHub Actions

1. Cliquer sur le workflow en rouge dans GitHub → Actions
2. Cliquer sur le job en échec pour voir les détails
3. Les erreurs les plus fréquentes :
   - **"Missing vars"** : une variable est manquante dans le `.env` du serveur
   - **"Connection refused"** : le serveur n'est pas accessible (vérifier la clé SSH)
   - **"SHA mismatch"** : relancer le déploiement (race condition rare)

### Réinitialiser complètement (tout effacer)

```bash
# ⚠️ Efface toutes les données (workflows, credentials, base de données)
make dev-reset
```

---

## Référence des variables d'environnement

| Variable | Obligatoire | Description | Exemple |
|---|---|---|---|
| `ONE_MIN_AI_API_KEY` | ✅ Toujours | Clé API 1min.ai | `sk-xxx...` |
| `TELEGRAM_BOT_TOKEN` | ✅ Toujours | Token du bot Telegram | `7123456789:AAF...` |
| `TELEGRAM_CHAT_ID` | ✅ Toujours | Ton Chat ID Telegram | `123456789` |
| `POSTGRES_USER` | ✅ Toujours | Nom d'utilisateur PostgreSQL | `chief` |
| `POSTGRES_PASSWORD` | ✅ Toujours | Mot de passe PostgreSQL (min 16 chars) | `MonSuperMotDePasse2026!` |
| `POSTGRES_DB` | ✅ Toujours | Nom de la base de données | `chief_db` |
| `N8N_ENCRYPTION_KEY` | ✅ Toujours | Clé de chiffrement n8n (min 32 chars) | *(généré avec openssl)* |
| `N8N_USER_MANAGEMENT_JWT_SECRET` | ✅ Toujours | Secret JWT n8n (min 32 chars) | *(généré avec openssl)* |
| `WEBHOOK_URL` | ✅ Toujours | URL publique du serveur n8n | `https://ton-domaine.com` |
| `COMPOSE_PROFILES` | ✅ Production | Active Caddy (HTTPS) | `tls` |
| `DOMAIN` | ✅ Production | Nom de domaine | `ton-domaine.com` |
| `ACME_EMAIL` | ✅ Production | Email pour Let's Encrypt | `admin@ton-domaine.com` |
| `PERMIT_MODELS_FROM_SUBSET_ONLY` | ⬜ Optionnel | Restreindre les modèles autorisés | `false` |
| `RATELIMIT_ENABLED` | ⬜ Optionnel | Activer le rate limiting sur la gateway | `false` |
| `LOG_LEVEL` | ⬜ Optionnel | Niveau de log de la gateway | `INFO` |
