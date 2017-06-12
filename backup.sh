#!/bin/bash
#===============================================================================
#
#          FILE: backup.sh
#
#         USAGE: ./backup.sh
#
#   DESCRIPTION: Dump Databases + Tar gz vhosts + rsync
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: Corentin (DevOps Engineer & Programmer)
#       CREATED: 12/06/2017 22:06:54
#      REVISION:  ---
#===============================================================================

# Script to place :
# /var/www/_backups/
#
# Create in that folder those dirs :
# databases
# logs
# logs_done

#############
# Variables #
#############

USER='admin'
PORT=22
HOST='1.2.3.4'
SITE='mywebsite'
DB_PATH='/home/admin/backups/'$SITE'/databases'
DATA_PATH='/home/admin/backups/'$SITE'/vhosts'
SITE_PATH="/var/www/vhosts"
LOG_DATE=`date +%Y-%m-%d:%H:%M:%S`
DATE=`date +%d-%m-%Y`
BACKUP_PATH="/var/www/_backups"


#################
# Script Backup #
#################


########################
# Si le fichier existe :
# - Process toujours en cours d'execution
# ou
# - Script kill a main
########################

if [ ! -f /var/www/_backups/logs/$DATE.log ]; then


  cd ${BACKUP_PATH}
    
  # Fichier de logs utilisé our la condition de start
  touch /var/www/_backups/logs/$DATE.log


  #######
  # BDD #
  #######

    
  # Dump Databases
  databases=`mysql -uadmin -p -e "SHOW DATABASES;" | tr -d "| " | grep -v Database`
        
  for db in $databases; do
      mysqldump -uadmin -p $db > ${BACKUP_PATH}/databases/db_backup_${db}_${DATE}.sql
  done

  ## Création du dossier du jour sur le serveur de backup
  ssh -t admin@1.2.3.4 -i "/home/admin/.ssh/id_rsa" -p22 "sudo mkdir -p $DB_PATH/$DATE && sudo chown -R admin:admin $DB_PATH"

  ## RSYNC des bases
  rsync -rtavz --stats --update $BACKUP_PATH/databases/ -e "ssh -p $PORT -i /home/admin/.ssh/id_rsa" $USER@$HOST:$DB_PATH/$DATE
    

  ##########
  # Vhosts #
  ##########


  # Créaion du dossier de récéption avec la date du jour
  ssh -t admin@1.2.3.4 -p22 -i "/home/admin/.ssh/id_rsa" "sudo mkdir -p $DATA_PATH/$DATE && sudo chown -R admin:admin $DATA_PATH"

  
  # Rsync de l'ensemble des dossiers dans /var/www/vhosts/
  cd /var/www/vhosts/
  for i in $(ls ${SITE_PATH}) ; do rsync -rRtavz --update $i -e "ssh -p $PORT -i /home/admin/.ssh/id_rsa" $USER@$HOST:$DATA_PATH/$DATE ; echo $LOG_DATE : $i - 'Done' >> /var/www/_backups/logs/$DATE.log ; done
  
  # FIN du script : On place le logs dans le rértoire de fin
  mv /var/www/_backups/logs/$DATE.log /var/www/_backups/logs_done/

  # Envoi du log success sur le serveur de backup
  ssh -t admin@1.2.3.4 -p22 -i "/home/admin/.ssh/id_rsa" "sudo touch /home/admin/backups/logs/$SITE-rsync_$DATE.log"


  ## Suppression des bases
  find ${BACKUP_PATH}/databases/db_backup_* -exec rm {} \;


# Si le fichier de log existe = Process en cours 
# Ou tué la main
# Exit
    
else
  exit 0
fi