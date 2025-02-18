#!/bin/bash

# Charger les variables depuis le fichier .env
set -a
source .env
set +a

# Vérifier les arguments
ACTION=$1
FROM=$2
TO=$3

# Vérification de l'action
if [[ "$ACTION" != "GET" && "$ACTION" != "PUT" ]]; then
  echo "Action invalide : Utilisez GET ou PUT."
  exit 1
fi

if [ -z "$FROM" ]; then
  echo "Usage : digiposte.sh [GET|PUT] [FROM] [TO]"
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
      URL=$DEV_URL
      ;;
    
    PREPROD)
      SSH_USER=$PREPROD_SSH_USER
      WP_DIR=$PREPROD_WP_DIR
      MYSQL_USER=$PREPROD_MYSQL_USER
      MYSQL_PASSWORD=$PREPROD_MYSQL_PASSWORD
      MYSQL_DB=$PREPROD_MYSQL_DB
      MYSQL_HOST=$PREPROD_MYSQL_HOST
      URL=$PREPROD_URL
      ;;
    
    PROD)
      SSH_USER=$PROD_SSH_USER
      WP_DIR=$PROD_WP_DIR
      MYSQL_USER=$PROD_MYSQL_USER
      MYSQL_PASSWORD=$PROD_MYSQL_PASSWORD
      MYSQL_DB=$PROD_MYSQL_DB
      MYSQL_HOST=$PROD_MYSQL_HOST
      URL=$PROD_URL
      ;;
    
    *)
      echo "Environnement invalide : DEV, PREPROD, PROD sont autorisés."
      exit 1
      ;;
  esac
}

# Fonction pour récupérer la version de WordPress
get_wp_version() {
  ssh $SSH_USER@$SSH_HOST "grep '\$wp_version =' $WP_DIR/wp-includes/version.php | awk -F\"'\" '{print \$2}'"
}

# Action GET : Récupérer les fichiers et la base de données de l'environnement FROM
if [ "$ACTION" == "GET" ]; then
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
  ssh $SSH_USER@$SSH_HOST "rm /tmp/$MYSQL_DB.sql"

  if [ $? -eq 0 ]; then
    echo "Transfert réussi avec rsync et dump de la base de données !"
  else
    echo "Erreur lors du transfert."
    exit 1
  fi

# Action PUT : Mettre à jour l'environnement TO avec le contenu de FROM
elif [ "$ACTION" == "PUT" ]; then
  if [ -z "$TO" ]; then
    echo "Veuillez spécifier un environnement d'arrivée (TO) pour l'action PUT."
    exit 1
  fi

  # Récupérer les informations des environnements FROM et TO
  get_env_info $FROM
  FROM_MYSQL_DB=$MYSQL_DB
  FROM_URL=$URL
  FROM_WP_VERSION=$(get_wp_version)

  get_env_info $TO
  TO_URL=$URL
  TO_WP_VERSION=$(get_wp_version)

  # Vérifier les versions de WordPress
  if [ "$FROM_WP_VERSION" != "$TO_WP_VERSION" ]; then
    echo "L'environnement $FROM est en version $FROM_WP_VERSION et l'environnement $TO est en version $TO_WP_VERSION."
    read -p "Souhaitez-vous continuer ? (oui/non) " REPLY
    if [[ "$REPLY" != "oui" ]]; then
      echo "Opération annulée."
      exit 1
    fi
  else
    echo "Les deux environnements sont en version WordPress $FROM_WP_VERSION."
  fi

  LOCAL_DIR="fichiers/$FROM"

  echo "Mise à jour de l'environnement $TO avec les fichiers de $FROM..."

  # Synchroniser les dossiers du répertoire local vers le serveur TO
  rsync -avz --delete $LOCAL_DIR/wp-content/themes/ $SSH_USER@$SSH_HOST:$WP_DIR/wp-content/themes/
  rsync -avz --delete $LOCAL_DIR/wp-content/plugins/ $SSH_USER@$SSH_HOST:$WP_DIR/wp-content/plugins/
  rsync -avz --delete $LOCAL_DIR/wp-content/uploads/ $SSH_USER@$SSH_HOST:$WP_DIR/wp-content/uploads/
  rsync -avz --delete $LOCAL_DIR/wp-content/languages/ $SSH_USER@$SSH_HOST:$WP_DIR/wp-content/languages/

  # Modifier l'URL dans le fichier SQL
  echo "Remplacement de toutes les occurrences de $FROM_URL par $TO_URL dans la base de données dumpée..."

  sed -i '' "s|$FROM_URL|$TO_URL|g" $LOCAL_DIR/SQL/$FROM_MYSQL_DB.sql

  # Mettre à jour la base de données
  echo "Mise à jour de la base de données $MYSQL_DB sur l'environnement $TO avec le dump de $FROM_MYSQL_DB..."

  scp $LOCAL_DIR/SQL/$FROM_MYSQL_DB.sql $SSH_USER@$SSH_HOST:/tmp/$FROM_MYSQL_DB.sql
  ssh $SSH_USER@$SSH_HOST "mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MYSQL_HOST --force $MYSQL_DB < /tmp/$FROM_MYSQL_DB.sql"
  ssh $SSH_USER@$SSH_HOST "rm /tmp/$FROM_MYSQL_DB.sql"

  if [ $? -eq 0 ]; then
    echo "Mise à jour réussie avec rsync et import de la base de données !"
  else
    echo "Erreur lors de la mise à jour."
    exit 1
  fi

fi