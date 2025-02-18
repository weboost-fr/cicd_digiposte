Voici le fichier README au format texte pour être consulté facilement dans un terminal :

README - Script digiposte.sh

Description

Le script digiposte.sh permet de transférer des fichiers et bases de données entre différents environnements d’un projet WordPress. Il utilise rsync pour synchroniser les fichiers et mysqldump/mysql pour gérer les bases de données. Le script gère trois environnements : DEV, PREPROD, et PROD.

Prérequis

	•	Un fichier .env avec les informations de connexion (utilisateur SSH, répertoires WordPress, utilisateurs MySQL, etc.) pour chaque environnement (DEV, PREPROD, PROD).
	•	Outils nécessaires : rsync, ssh, et mysqldump.
	•	Accès SSH configuré entre les environnements.

Utilisation

Lancer le script avec la syntaxe suivante :

./digiposte.sh [GET|PUT] [FROM] [TO]

Paramètres

	•	ACTION : GET ou PUT
	•	GET : Récupère les fichiers et la base de données de l’environnement FROM.
	•	PUT : Met à jour l’environnement TO avec le contenu de FROM.
	•	FROM : Environnement source (DEV, PREPROD, PROD).
	•	TO : Environnement cible pour l’action PUT.

Fichier .env

Le fichier .env doit contenir les informations de configuration pour chaque environnement, par exemple :

DEV_SSH_USER=username_dev
DEV_SSH_HOST=host_dev
DEV_WP_DIR=/chemin/vers/dev/wp
DEV_MYSQL_USER=dev_user
DEV_MYSQL_PASSWORD=dev_password
DEV_MYSQL_DB=dev_db
DEV_MYSQL_HOST=localhost
DEV_URL=http://dev.example.com

PREPROD_SSH_USER=username_preprod
...

Fonctionnement du Script

Vérification des Arguments

Le script vérifie les arguments d’entrée :

	•	Il s’assure que ACTION est GET ou PUT.
	•	Il vérifie que FROM est valide (DEV, PREPROD, PROD).
	•	Si ACTION est PUT, il vérifie que TO est bien spécifié.

Fonction get_env_info

Cette fonction récupère les informations de configuration pour un environnement (DEV, PREPROD, PROD) et les stocke dans des variables.

Fonction get_wp_version

Cette fonction utilise SSH pour obtenir la version de WordPress dans l’environnement.

Action GET

L’action GET :

	1.	Récupère les informations de l’environnement FROM.
	2.	Crée les répertoires locaux nécessaires.
	3.	Synchronise les dossiers wp-content/themes, wp-content/plugins, wp-content/uploads, et wp-content/languages depuis FROM vers le répertoire local.
	4.	Crée un dump de la base de données et le copie dans le répertoire local.

Action PUT

L’action PUT :

	1.	Vérifie les versions de WordPress entre FROM et TO. En cas de différences, demande confirmation.
	2.	Synchronise les dossiers du répertoire local vers TO.
	3.	Remplace les URL de FROM par celles de TO dans le fichier SQL.
	4.	Met à jour la base de données TO avec le dump de FROM.

Exemple d’Exécution

# Récupérer les fichiers et la base de données de l'environnement DEV
./digiposte.sh GET DEV

# Mettre à jour l'environnement PROD avec les fichiers et la base de données de l'environnement PREPROD
./digiposte.sh PUT PREPROD PROD

Gestion des Erreurs

	•	Si une action invalide est fournie (ACTION autre que GET ou PUT), le script affiche un message d’erreur.
	•	En cas d’échec d’une opération rsync ou de dump de la base de données, un message d’erreur est affiché, et le script s’arrête.

