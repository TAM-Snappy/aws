#!/bin/bash

sshopts="-o StrictHostKeyChecking=no"
nas="/mnt/nasdata/tables/"

ippublic=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=DOKEVAX-PROD" | grep -iEo '\"PublicIpAddress\"\: \"[0-9.]+\"' | cut -d " " -f 2 | sed 's/"//g')
echo $ippublic


echo "$(ssh $sshopts ubuntu@$ippublic 'sudo mysql -e "use sample; show tables \G" | grep "Tables" | cut -d " " -f2')"

while IFS= read -r table; do

echo "Vérification de la table - $table"
nas="/mnt/nasdata/tables/$table/"
repbkp=$(ls $nas -t | head -n 1)
lastbkp=$(ls $nas"$repbkp")


#DUMP DE BD
ssh $sshopts ubuntu@$ippublic 'sudo mysqldump sample $table < /dev/null > $table.sql'

sleep 10

scp $sshopts ubuntu@$ippublic:/home/ubuntu/$table.sql . < /dev/null



if ! [ -d $nas ]; then
       
    
    echo "aucune backup de la table -$table, lancement d'une sauvegarde"
    
	mkdir -p $nas"$(date)" 
	cp $table.sql $nas"$(date)"/$table.sql 
	echo "sauvegarde de la table - $table terminée"


else


	#VERIFICATION DE CHANGEMENT DANS BD AVANT DEPLACEMENT DANS LE NAS


	nb_ligne1=$(cat $table.sql | wc -l)
	
    nb_ligne2=$(cat "$nas$repbkp/$lastbkp" | wc -l)
	
	var1=$(($nb_ligne1 - 1))

	head -n $var1 $table.sql > save_${table}1.sql

	var2=$(($nb_ligne2 - 1))

	head -n $var2 "$nas$repbkp/$lastbkp" > save_${lastbkp}2.sql
	
	sv1=$(md5sum save_${table}1.sql | cut -d ' ' -f1)
	sv2=$(md5sum save_${lastbkp}2.sql | cut -d ' ' -f1)
	

	if [ "$sv1" == "$sv2" ]; then

		echo "aucune nouvelle modification sur la bdd"

	else

		#DEPLACEMENT DANS LE NAS
		
		echo "modification detecté sur la bdd"
		mkdir -p $nas"$(date)" 
		cp sample.sql $nas"$(date)/$table.sql" 
		echo "sauvegarde de la table - $table terminée"

	fi
    
   echo "debug 0"
fi

echo "debug 1"
done < <(ssh $sshopts ubuntu@$ippublic 'sudo mysql -e "use sample; show tables \G" | grep "Tables" | cut -d " " -f2')

