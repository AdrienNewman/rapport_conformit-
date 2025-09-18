#!/bin/bash

#############################################################################
# Script de génération de rapport de conformité matériel
# Auteur : Adrien Mercadier
# Date : $(date)
# Description : Ce script analyse l'inventaire du parc informatique et génère
#               un rapport de conformité identifiant :
#               - Les machines Windows 10 nécessitant une mise à jour
#               - Les machines avec 8 Go de RAM ou moins
#############################################################################

# Configuration des couleurs pour l'affichage (améliore la lisibilité)
RED='\033[0;31m'       # Rouge pour les alertes critiques
YELLOW='\033[1;33m'    # Jaune pour les avertissements
GREEN='\033[0;32m'     # Vert pour les informations positives
BLUE='\033[0;34m'      # Bleu pour les titres
NC='\033[0m'           # No Color - annule les couleurs

# Variables de configuration
FICHIER_INVENTAIRE="inventaire_parc_informatique.csv"  # Fichier source des données
FICHIER_LOGS="logs_systeme_parc.csv"                  # Fichier des logs système
RAPPORT_SORTIE="rapport_conformite_$(date +%Y%m%d_%H%M%S).txt"  # Fichier de sortie avec horodatage

# Fonction pour afficher un en-tête formaté
afficher_entete() {
    echo -e "${BLUE}==============================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}==============================================================${NC}"
}

# Fonction pour vérifier l'existence des fichiers requis
verifier_fichiers() {
    local fichiers_manquants=0
    
    echo -e "${BLUE}[INFO]${NC} Vérification de la présence des fichiers requis..."
    
    # Vérification du fichier inventaire
    if [ ! -f "$FICHIER_INVENTAIRE" ]; then
        echo -e "${RED}[ERREUR]${NC} Fichier inventaire non trouvé : $FICHIER_INVENTAIRE"
        fichiers_manquants=1
    else
        echo -e "${GREEN}[OK]${NC} Fichier inventaire trouvé : $FICHIER_INVENTAIRE"
    fi
    
    # Vérification du fichier de logs
    if [ ! -f "$FICHIER_LOGS" ]; then
        echo -e "${YELLOW}[ATTENTION]${NC} Fichier logs non trouvé : $FICHIER_LOGS"
        echo -e "${YELLOW}[INFO]${NC} Le rapport sera généré uniquement avec les données d'inventaire"
    else
        echo -e "${GREEN}[OK]${NC} Fichier logs trouvé : $FICHIER_LOGS"
    fi
    
    # Arrêt du script si le fichier inventaire est manquant
    if [ $fichiers_manquants -eq 1 ]; then
        echo -e "${RED}[ERREUR CRITIQUE]${NC} Impossible de continuer sans le fichier inventaire"
        exit 1
    fi
}

# Fonction pour analyser les machines Windows 10
analyser_windows10() {
    echo -e "${BLUE}[ANALYSE]${NC} Recherche des machines Windows 10 nécessitant une mise à jour..."
    
    # Compter le nombre total de machines Windows 10
    # grep -v "^IP" exclut l'en-tête du CSV
    # grep -i "windows 10" recherche Windows 10 (insensible à la casse)
    # wc -l compte le nombre de lignes
    local nb_windows10=$(grep -v "^IP" "$FICHIER_INVENTAIRE" | grep -i "windows 10" | wc -l)
    
    echo "MACHINES WINDOWS 10 À METTRE À JOUR" >> "$RAPPORT_SORTIE"
    echo "===================================" >> "$RAPPORT_SORTIE"
    echo "Nombre total de machines Windows 10 : $nb_windows10" >> "$RAPPORT_SORTIE"
    echo "" >> "$RAPPORT_SORTIE"
    
    # Si des machines Windows 10 sont trouvées
    if [ $nb_windows10 -gt 0 ]; then
        echo -e "${YELLOW}[ATTENTION]${NC} $nb_windows10 machine(s) Windows 10 nécessite(nt) une mise à jour vers Windows 11"
        
        # Détail par département
        echo "Répartition par département :" >> "$RAPPORT_SORTIE"
        echo "----------------------------" >> "$RAPPORT_SORTIE"
        
        # awk permet de traiter le fichier CSV colonne par colonne
        # NR>1 ignore la première ligne (en-tête)
        # $5 correspond à la colonne OS, $6 au département
        # tolower() convertit en minuscules pour la comparaison
        grep -v "^IP" "$FICHIER_INVENTAIRE" | awk -F',' '
        tolower($5) ~ /windows 10/ {
            dept[$6]++  # Incrémente le compteur pour chaque département
        }
        END {
            for (d in dept) {
                printf "- %s : %d machine(s)\n", d, dept[d]
            }
        }' >> "$RAPPORT_SORTIE"
        
        echo "" >> "$RAPPORT_SORTIE"
        echo "Liste détaillée des machines Windows 10 :" >> "$RAPPORT_SORTIE"
        echo "Format: IP | RAM | Utilisateur | Âge | Département" >> "$RAPPORT_SORTIE"
        echo "-" >> "$RAPPORT_SORTIE"
        
        # Affichage détaillé de chaque machine Windows 10
        grep -v "^IP" "$FICHIER_INVENTAIRE" | grep -i "windows 10" | while IFS=',' read -r ip ram user age os dept anciennete; do
            echo "$ip | ${ram}GB | $user | ${age} an(s) | $dept" >> "$RAPPORT_SORTIE"
        done
        
    else
        echo -e "${GREEN}[OK]${NC} Aucune machine Windows 10 trouvée - Parc à jour !"
        echo "Aucune machine Windows 10 détectée." >> "$RAPPORT_SORTIE"
    fi
    
    echo "" >> "$RAPPORT_SORTIE"
}

# Fonction pour analyser les machines avec RAM insuffisante
analyser_ram_faible() {
    echo -e "${BLUE}[ANALYSE]${NC} Recherche des machines avec 8 Go de RAM ou moins..."
    
    # Compter les machines avec 8GB de RAM ou moins
    # awk traite le fichier CSV et vérifie la colonne RAM ($2)
    local nb_ram_faible=$(grep -v "^IP" "$FICHIER_INVENTAIRE" | awk -F',' '$2 <= 8' | wc -l)
    
    echo "MACHINES AVEC RAM INSUFFISANTE (≤ 8 Go)" >> "$RAPPORT_SORTIE"
    echo "=======================================" >> "$RAPPORT_SORTIE"
    echo "Nombre total de machines avec ≤ 8 Go RAM : $nb_ram_faible" >> "$RAPPORT_SORTIE"
    echo "" >> "$RAPPORT_SORTIE"
    
    if [ $nb_ram_faible -gt 0 ]; then
        echo -e "${YELLOW}[ATTENTION]${NC} $nb_ram_faible machine(s) avec une quantité de RAM insuffisante"
        
        # Répartition par département
        echo "Répartition par département :" >> "$RAPPORT_SORTIE"
        echo "----------------------------" >> "$RAPPORT_SORTIE"
        
        grep -v "^IP" "$FICHIER_INVENTAIRE" | awk -F',' '
        $2 <= 8 {
            dept[$6]++
        }
        END {
            for (d in dept) {
                printf "- %s : %d machine(s)\n", d, dept[d]
            }
        }' >> "$RAPPORT_SORTIE"
        
        echo "" >> "$RAPPORT_SORTIE"
        echo "Liste détaillée des machines avec RAM insuffisante :" >> "$RAPPORT_SORTIE"
        echo "Format: IP | RAM | Utilisateur | OS | Département" >> "$RAPPORT_SORTIE"
        echo "-" >> "$RAPPORT_SORTIE"
        
        # Affichage détaillé trié par quantité de RAM (plus critique en premier)
        grep -v "^IP" "$FICHIER_INVENTAIRE" | awk -F',' '$2 <= 8' | sort -t',' -k2,2n | while IFS=',' read -r ip ram user age os dept anciennete; do
            # Marquage spécial pour les machines très critiques (4GB ou moins)
            if [ "$ram" -le 4 ]; then
                echo "$ip | ${ram}GB RAM [CRITIQUE] | $user | $os | $dept" >> "$RAPPORT_SORTIE"
            else
                echo "$ip | ${ram}GB RAM | $user | $os | $dept" >> "$RAPPORT_SORTIE"
            fi
        done
        
    else
        echo -e "${GREEN}[OK]${NC} Toutes les machines ont plus de 8 Go de RAM"
        echo "Toutes les machines disposent de plus de 8 Go de RAM." >> "$RAPPORT_SORTIE"
    fi
    
    echo "" >> "$RAPPORT_SORTIE"
}

# Fonction pour analyser les machines avec problèmes multiples (Windows 10 ET RAM faible)
analyser_problemes_multiples() {
    echo -e "${BLUE}[ANALYSE]${NC} Recherche des machines avec problèmes multiples..."
    
    # Machines ayant à la fois Windows 10 ET 8GB de RAM ou moins
    local nb_problemes_multiples=$(grep -v "^IP" "$FICHIER_INVENTAIRE" | awk -F',' 'tolower($5) ~ /windows 10/ && $2 <= 8' | wc -l)
    
    echo "MACHINES AVEC PROBLÈMES MULTIPLES" >> "$RAPPORT_SORTIE"
    echo "=================================" >> "$RAPPORT_SORTIE"
    echo "Machines Windows 10 avec ≤ 8 Go RAM : $nb_problemes_multiples" >> "$RAPPORT_SORTIE"
    echo "" >> "$RAPPORT_SORTIE"
    
    if [ $nb_problemes_multiples -gt 0 ]; then
        echo -e "${RED}[CRITIQUE]${NC} $nb_problemes_multiples machine(s) nécessite(nt) une attention prioritaire !"
        
        echo "Ces machines nécessitent une mise à jour système ET une augmentation de RAM :" >> "$RAPPORT_SORTIE"
        echo "-" >> "$RAPPORT_SORTIE"
        
        grep -v "^IP" "$FICHIER_INVENTAIRE" | awk -F',' 'tolower($5) ~ /windows 10/ && $2 <= 8' | while IFS=',' read -r ip ram user age os dept anciennete; do
            echo "[PRIORITÉ HAUTE] $ip | ${ram}GB RAM | $user | $dept" >> "$RAPPORT_SORTIE"
        done
        
    else
        echo -e "${GREEN}[OK]${NC} Aucune machine ne cumule les deux problèmes"
        echo "Aucune machine ne cumule Windows 10 et RAM insuffisante." >> "$RAPPORT_SORTIE"
    fi
    
    echo "" >> "$RAPPORT_SORTIE"
}

# Fonction pour générer des recommandations
generer_recommandations() {
    echo -e "${BLUE}[GÉNÉRATION]${NC} Création des recommandations..."
    
    echo "RECOMMANDATIONS D'ACTIONS" >> "$RAPPORT_SORTIE"
    echo "========================" >> "$RAPPORT_SORTIE"
    echo "" >> "$RAPPORT_SORTIE"
    
    echo "1. MISE À JOUR SYSTÈME :" >> "$RAPPORT_SORTIE"
    echo "   - Planifier la migration des machines Windows 10 vers Windows 11" >> "$RAPPORT_SORTIE"
    echo "   - Vérifier la compatibilité matérielle avant migration" >> "$RAPPORT_SORTIE"
    echo "   - Prioriser les départements avec le plus de machines concernées" >> "$RAPPORT_SORTIE"
    echo "" >> "$RAPPORT_SORTIE"
    
    echo "2. AMÉLIORATION MATÉRIELLE :" >> "$RAPPORT_SORTIE"
    echo "   - Remplacer ou upgrader les machines avec 4 Go de RAM (critique)" >> "$RAPPORT_SORTIE"
    echo "   - Planifier l'augmentation à 16 Go minimum pour les machines 8 Go" >> "$RAPPORT_SORTIE"
    echo "   - Considérer le remplacement des machines de plus de 4 ans" >> "$RAPPORT_SORTIE"
    echo "" >> "$RAPPORT_SORTIE"
    
    echo "3. PRIORITÉS :" >> "$RAPPORT_SORTIE"
    echo "   - Traiter en URGENT les machines avec problèmes multiples" >> "$RAPPORT_SORTIE"
    echo "   - Départements techniques : priorité sur les performances" >> "$RAPPORT_SORTIE"
    echo "   - Prévoir un budget pour les remplacements nécessaires" >> "$RAPPORT_SORTIE"
    echo "" >> "$RAPPORT_SORTIE"
}

# Fonction pour générer les statistiques globales
generer_statistiques() {
    echo -e "${BLUE}[STATISTIQUES]${NC} Calcul des statistiques globales..."
    
    local total_machines=$(grep -v "^IP" "$FICHIER_INVENTAIRE" | wc -l)
    local total_windows10=$(grep -v "^IP" "$FICHIER_INVENTAIRE" | grep -i "windows 10" | wc -l)
    local total_ram_faible=$(grep -v "^IP" "$FICHIER_INVENTAIRE" | awk -F',' '$2 <= 8' | wc -l)
    local total_critique=$(grep -v "^IP" "$FICHIER_INVENTAIRE" | awk -F',' '$2 <= 4' | wc -l)
    
    echo "STATISTIQUES GÉNÉRALES" >> "$RAPPORT_SORTIE"
    echo "=====================" >> "$RAPPORT_SORTIE"
    echo "Total machines dans le parc : $total_machines" >> "$RAPPORT_SORTIE"
    echo "Machines Windows 10 : $total_windows10 ($(( total_windows10 * 100 / total_machines ))%)" >> "$RAPPORT_SORTIE"
    echo "Machines RAM ≤ 8 Go : $total_ram_faible ($(( total_ram_faible * 100 / total_machines ))%)" >> "$RAPPORT_SORTIE"
    echo "Machines RAM ≤ 4 Go (critique) : $total_critique ($(( total_critique * 100 / total_machines ))%)" >> "$RAPPORT_SORTIE"
    echo "" >> "$RAPPORT_SORTIE"
    
    # Calcul du score de conformité (pourcentage de machines conformes)
    local machines_conformes=$(( total_machines - total_windows10 - total_ram_faible ))
    # Éviter la double comptabilisation des machines avec les deux problèmes
    local machines_problemes_multiples=$(grep -v "^IP" "$FICHIER_INVENTAIRE" | awk -F',' 'tolower($5) ~ /windows 10/ && $2 <= 8' | wc -l)
    machines_conformes=$(( machines_conformes + machines_problemes_multiples ))
    
    local score_conformite=$(( machines_conformes * 100 / total_machines ))
    
    echo "SCORE DE CONFORMITÉ : $score_conformite%" >> "$RAPPORT_SORTIE"
    echo "" >> "$RAPPORT_SORTIE"
    
    if [ $score_conformite -ge 80 ]; then
        echo -e "${GREEN}[EXCELLENT]${NC} Score de conformité : $score_conformite%"
    elif [ $score_conformite -ge 60 ]; then
        echo -e "${YELLOW}[CORRECT]${NC} Score de conformité : $score_conformite%"
    else
        echo -e "${RED}[INSUFFISANT]${NC} Score de conformité : $score_conformite%"
    fi
}

# Fonction principale d'exécution du script
main() {
    # Affichage de l'en-tête du script
    afficher_entete "RAPPORT DE CONFORMITÉ MATÉRIEL - $(date '+%d/%m/%Y %H:%M:%S')"
    
    # Initialisation du fichier de rapport
    echo "RAPPORT DE CONFORMITÉ MATÉRIEL" > "$RAPPORT_SORTIE"
    echo "Date de génération : $(date '+%d/%m/%Y %H:%M:%S')" >> "$RAPPORT_SORTIE"
    echo "Généré par : $(whoami) sur $(hostname)" >> "$RAPPORT_SORTIE"
    echo "" >> "$RAPPORT_SORTIE"
    
    # Exécution des différentes analyses
    verifier_fichiers
    analyser_windows10
    analyser_ram_faible
    analyser_problemes_multiples
    generer_recommandations
    generer_statistiques
    
    # Finalisation
    echo "Rapport généré dans : $RAPPORT_SORTIE" >> "$RAPPORT_SORTIE"
    
    afficher_entete "RAPPORT GÉNÉRÉ AVEC SUCCÈS"
    echo -e "${GREEN}[SUCCÈS]${NC} Le rapport a été généré : $RAPPORT_SORTIE"
    echo -e "${BLUE}[INFO]${NC} Vous pouvez consulter le rapport avec : cat $RAPPORT_SORTIE"
    echo -e "${BLUE}[INFO]${NC} Ou l'ouvrir avec votre éditeur préféré : nano $RAPPORT_SORTIE"
}

# Point d'entrée du script
# Cette condition vérifie que le script est exécuté directement (pas sourcé)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"  # Appel de la fonction main avec tous les arguments passés au script
fi

# Question pour afficher le rapport dans le terminal
echo -n "Voulez-vous afficher le rapport maintenant ? (o/N) : "
read reponse
if [[ "$reponse" =~ ^[oO]$ ]]; then
    echo -e "\n${BLUE}--- Contenu du rapport ---${NC}\n"
    cat "$RAPPORT_SORTIE"
    echo -e "\n${BLUE}--- Fin du rapport ---${NC}\n"
else
    echo "Affichage du rapport annulé."
fi
