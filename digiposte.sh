#!/bin/bash

# Charger les variables depuis le fichier .env
set -a
source .env
set +a

# Vérifier l'argument FROM
FROM=$1

if [ -z "$FROM" ]; then
  echo "Veuillez spécifier un environnement de départ (FROM) : DEV, PREPROD, PROD"
  exit 1
fi

# Fonction pour récupérer les informations d'un environnement
get_env_info() {
  local env=$1
  case $env in
    DEV)
      SSH_USER=$DEV_SSH_USER
      WP_DIR=$DEV_WP_DIR
      MYSQL_USER=$DEV_MYSQL_USER
      MYSQL_PASSWORD=$DEV_MYSQL_PASSWORD
      MYSQL_DB=$DEV_MYSQL_DB
      MYSQL_HOST=$DEV_MYSQL_HOST
      ;;
    
    PREPROD)
      SSH_USER=$PREPROD_SSH_USER
      WP_DIR=$PREPROD_WP_DIR
      MYSQL_USER=$PREPROD_MYSQL_USER
      MYSQL_PASSWORD=$PREPROD_MYSQL_PASSWORD
      MYSQL_DB=$PREPROD_MYSQL_DB
      MYSQL_HOST=$PREPROD_MYSQL_HOST
      ;;
    
    PROD)
      SSH_USER=$PROD_SSH_USER
      WP_DIR=$PROD_WP_DIR
      MYSQL_USER=$PROD_MYSQL_USER
      MYSQL_PASSWORD=$PROD_MYSQL_PASSWORD
      MYSQL_DB=$PROD_MYSQL_DB
      MYSQL_HOST=$PROD_MYSQL_HOST
      ;;
    
    *)
      echo "Environnement invalide : DEV, PREPROD, PROD sont autorisés."
      exit 1
      ;;
  esac
}

# Récupérer les informations de l'environnement FROM
get_env_info $FROM

# Définir le répertoire local de destination pour l'environnement FROM
LOCAL_DIR="fichiers/$FROM"
SQL_DIR="$LOCAL_DIR/SQL"

# Créer les sous-répertoires nécessaires si besoin
mkdir -p $LOCAL_DIR/wp-content/themes
mkdir -p $LOCAL_DIR/wp-content/plugins
mkdir -p $LOCAL_DIR/wp-content/uploads
mkdir -p $LOCAL_DIR/wp-content/languages
mkdir -p $SQL_DIR

# Synchroniser uniquement les dossiers spécifiés dans wp-content
echo "Synchronisation des dossiers wp-content/themes, wp-content/plugins, wp-content/uploads, wp-content/languages de l'environnement $FROM vers le répertoire local $LOCAL_DIR..."

rsync -avz --delete $SSH_USER@$SSH_HOST:$WP_DIR/wp-content/themes/ $LOCAL_DIR/wp-content/themes/
rsync -avz --delete $SSH_USER@$SSH_HOST:$WP_DIR/wp-content/plugins/ $LOCAL_DIR/wp-content/plugins/
rsync -avz --delete $SSH_USER@$SSH_HOST:$WP_DIR/wp-content/uploads/ $LOCAL_DIR/wp-content/uploads/
rsync -avz --delete $SSH_USER@$SSH_HOST:$WP_DIR/wp-content/languages/ $LOCAL_DIR/wp-content/languages/

# Créer un dump de la base de données
echo "Création d'un dump de la base de données $MYSQL_DB sur l'environnement $FROM..."

ssh $SSH_USER@$SSH_HOST "mysqldump -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MYSQL_HOST $MYSQL_DB > /tmp/$MYSQL_DB.sql"

# Récupérer le dump dans le répertoire local
echo "Récupération du dump de la base de données dans $SQL_DIR..."

scp $SSH_USER@$SSH_HOST:/tmp/$MYSQL_DB.sql $SQL_DIR/

# Supprimer le dump du serveur distant
ssh $SSH_USER@$SSH_HOST "rm /tmp/$MYSQL_DB.sql"

if [ $? -eq 0 ]; then
  echo "Dump et transfert réussi de la base de données avec scp !"
else
  echo "Erreur lors du dump ou du transfert de la base de données."
  exit 1
fi

if [ $? -eq 0 ]; then
  echo "Transfert réussi avec rsync et dump de la base de données !"
else
  echo "Erreur lors du transfert avec rsync."
  exit 1
fi