#!/usr/bin/env bash
# Script de build execute par l'hebergeur (Render / Railway / Koyeb).
# Installe les dependances, collecte les fichiers statiques, applique les migrations.
set -o errexit

pip install --upgrade pip
pip install -r requirements.txt

python manage.py collectstatic --noinput
python manage.py migrate --noinput
