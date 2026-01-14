#!/bin/bash
# Setup HandyJob Production Server - Version corrigée
# Usage: bash setup.sh

set -e  # Arrête le script en cas d'erreur

echo "🚀 Début du setup serveur HandyJob..."

# ============================================
# 1. Update système
# ============================================
echo "📦 Mise à jour du système..."
apt update && apt upgrade -y

# ============================================
# 2. Installation des packages essentiels
# ============================================
echo "📦 Installation des packages de base..."
apt install -y \
    ufw \
    fail2ban \
    git \
    vim \
    htop \
    curl \
    wget \
    unzip \
    ca-certificates \
    gnupg \
    lsb-release

# ============================================
# 3. Installation Docker (méthode officielle)
# ============================================
echo "🐳 Installation de Docker (version officielle)..."

# Supprimer les anciennes versions si présentes
apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

# Ajouter la clé GPG officielle de Docker
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# Ajouter le dépôt Docker
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

# Mettre à jour et installer Docker
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Activer Docker
systemctl enable docker
systemctl start docker

echo "✅ Docker installé avec succès"

# ============================================
# 4. Création utilisateur nicolas
# ============================================
echo "👤 Création de l'utilisateur nicolas..."

# Créer l'utilisateur sans mot de passe interactif
if id "nicolas" &>/dev/null; then
    echo "⚠️  L'utilisateur nicolas existe déjà, on continue..."
else
    useradd -m -s /bin/bash nicolas
fi
# Ajouter aux groupes sudo et docker
usermod -aG sudo,docker nicolas

# Générer un mot de passe aléatoire fort (32 caractères)
RANDOM_PASSWORD=$(openssl rand -base64 32)
echo "nicolas:$RANDOM_PASSWORD" | chpasswd

# Sauvegarder le mot de passe dans un fichier sécurisé
echo "⚠️  Mot de passe généré pour nicolas (À NOTER ET SUPPRIMER CE FICHIER) :" > /root/nicolas_password.txt
echo "$RANDOM_PASSWORD" >> /root/nicolas_password.txt
chmod 600 /root/nicolas_password.txt

echo "✅ Mot de passe aléatoire généré et sauvegardé dans /root/nicolas_password.txt"
echo "   IMPORTANT : Note ce mot de passe et supprime le fichier après !"

# ============================================
# 5. Configuration SSH pour nicolas
# ============================================
echo "🔑 Configuration des clés SSH..."

# Créer le dossier .ssh pour nicolas
mkdir -p /home/nicolas/.ssh
chmod 700 /home/nicolas/.ssh

# Copier la clé SSH de root vers nicolas
if [ -f /root/.ssh/authorized_keys ]; then
    cp /root/.ssh/authorized_keys /home/nicolas/.ssh/authorized_keys
    chmod 600 /home/nicolas/.ssh/authorized_keys
    chown -R nicolas:nicolas /home/nicolas/.ssh
    echo "✅ Clé SSH copiée de root vers nicolas"
else
    echo "⚠️  ATTENTION : Aucune clé SSH trouvée dans /root/.ssh/authorized_keys"
    echo "   Tu devras ajouter ta clé manuellement avant de désactiver root SSH !"
fi

# ============================================
# 6. Configuration sudo sans mot de passe
# ============================================
echo "🔐 Configuration sudo pour nicolas..."
echo "nicolas ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/nicolas
chmod 440 /etc/sudoers.d/nicolas

# ============================================
# 7. Sécurisation SSH
# ============================================
echo "🔒 Sécurisation SSH..."

# Backup de la config SSH
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

# Désactiver connexion root
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config

# Désactiver authentification par mot de passe
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config

# S'assurer que l'authentification par clé est activée
sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# Désactiver l'authentification par challenge-response
sed -i 's/^#*ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#*KbdInteractiveAuthentication.*/KbdInteractiveAuthentication no/' /etc/ssh/sshd_config

echo "✅ SSH sécurisé : root disabled, password auth disabled"

# ============================================
# 8. Configuration Firewall (UFW)
# ============================================
echo "🔥 Configuration du firewall..."

# Reset UFW si déjà configuré
ufw --force reset

# Politique par défaut : tout bloquer sauf sortant
ufw default deny incoming
ufw default allow outgoing

# Autoriser SSH (IMPORTANT : avant d'activer UFW !)
ufw allow 22/tcp comment 'SSH'

# Autoriser HTTP/HTTPS
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'

# Activer UFW
ufw --force enable

echo "✅ Firewall configuré et activé"

# ============================================
# 9. Configuration Fail2ban
# ============================================
echo "🛡️  Configuration Fail2ban..."

# Créer une config locale pour SSH
cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
port = 22
logpath = %(sshd_log)s
backend = %(sshd_backend)s
EOF

# Redémarrer fail2ban
systemctl enable fail2ban
systemctl restart fail2ban

echo "✅ Fail2ban configuré (5 tentatives max, ban 1h)"

# ============================================
# 10. Redémarrage SSH (ATTENTION !)
# ============================================
echo ""
echo "⚠️  =========================================="
echo "⚠️  ATTENTION : Le service SSH va redémarrer !"
echo "⚠️  =========================================="
echo ""
echo "Avant de continuer, VÉRIFIE que :"
echo "  1. Tu peux te connecter avec : ssh nicolas@$(hostname -I | awk '{print $1}')"
echo "  2. Ta clé SSH est bien dans /home/nicolas/.ssh/authorized_keys"
echo "  3. Tu as noté le mot de passe dans /root/nicolas_password.txt"
echo ""
read -p "Appuie sur ENTRÉE pour redémarrer SSH (ou CTRL+C pour annuler)..." 

systemctl restart ssh

echo ""
echo "✅ SSH redémarré avec la nouvelle configuration"

# ============================================
# 11. Récapitulatif final
# ============================================
echo ""
echo "=========================================="
echo "✅ Setup terminé avec succès !"
echo "=========================================="
echo ""
echo "📋 Récapitulatif :"
echo "  • Utilisateur créé : nicolas"
echo "  • Mot de passe aléatoire : /root/nicolas_password.txt"
echo "  • Clé SSH copiée de root → nicolas"
echo "  • SSH root : DÉSACTIVÉ"
echo "  • SSH password : DÉSACTIVÉ"
echo "  • Firewall : actif (ports 22, 80, 443)"
echo "  • Fail2ban : actif"
echo "  • Docker : installé et actif (version officielle)"
echo ""
echo "🔐 PROCHAINES ÉTAPES :"
echo "  1. Teste la connexion : ssh nicolas@$(hostname -I | awk '{print $1}')"
echo "  2. Note le mot de passe : cat /root/nicolas_password.txt"
echo "  3. Supprime le fichier : rm /root/nicolas_password.txt"
echo "  4. Déconnecte-toi de root et travaille avec nicolas"
echo "  5. Teste Docker : docker run hello-world"
echo ""
echo "⚠️  RECOMMANDATION : Redémarre le serveur pour charger le nouveau kernel"
echo "   sudo reboot"
echo ""
echo "⚠️  NE FERME PAS cette session avant d'avoir testé !"
echo "=========================================="