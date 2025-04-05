#!/bin/bash

# Definisci le estensioni di lingua
languages=("en" "es" "ru" "de" "fr")

# Definisci la cartella di destinazione
destination_folder="./assets/personas"

# Crea la cartella di destinazione se non esiste
mkdir -p "$destination_folder"

# Trova tutti i file che corrispondono al pattern "XX.json" nella cartella corrente
for file in $(find . -type f -name "[0-9][0-9].json"); do
  # Ottieni il nome del file senza l'estensione .json
  filename=$(basename "$file" .json)

  # Per ogni lingua, copia il file con il nuovo nome nella cartella di destinazione
  for lang in "${languages[@]}"; do
    new_filename="${filename}_${lang}.json"
    cp "$file" "$destination_folder/$new_filename"
    echo "Creato $destination_folder/$new_filename da $file"
  done
done

echo "Operazione completata."