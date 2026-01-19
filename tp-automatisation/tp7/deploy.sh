#!/bin/bash

echo "--- Etape 1 : Deploiement de l'Infrastructure avec Terraform ---"
terraform init
terraform apply -auto-approve

echo ""
echo "--- Etape 2 : Verification de l'inventaire genere ---"
cat inventory.ini

echo ""
echo "--- Etape 3 : Configuration avec Ansible ---"
sleep 5
ansible-playbook -i inventory.ini playbook.yml

echo ""
echo "--- Deploiement termine ! ---"
echo "Accedez a votre application ici : http://localhost:8080"
