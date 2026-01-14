# Script to setup and harden a server

Launch just after an instance is created

> [!IMPORTANT]
Prerequisite : 
A SSH Key generated (and copied from your own .ssh folder of your client terminal) when the instance is created (to copy it from root to user)

> [!NOTE]
"nicolas" is the user created, change the name if you want a different user account. 

Steps :
## Crée un nouveau fichier
```
nano setup.sh
```
## Colle le script ci-dessus du fichier setup.sh du dépôt

## Rends-le exécutable
```
chmod +x setup.sh
```
## Lance-le
```
bash setup.sh
```

> [!WARNING]
You have to test your user ssh connection before leaving the root ssh access.
ssh nicolas@ip | hostname

> [!WARNING]
You have to copy the password generated for the user : 
```
cat /root/nicolas_password.txt
rm /root/nicolas_password.txt"
```
