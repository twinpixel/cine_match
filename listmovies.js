const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');



const crypto = require('crypto'); // Aggiunto per generare nomi di file casuali

// Funzione per leggere il contenuto del file JSON
function readFileContent(filePath) {
  try {
    const data = fs.readFileSync(filePath, 'utf8');
    return JSON.parse(data);
  } catch (error) {
    console.error('Errore nella lettura del file:', error);
    return null;
  }
}

// Funzione per eseguire la chiamata curl
function executeCurlCommand(systemContent, dettagli) {
  const curlCommand = `curl --request POST \
    --url https://text.pollinations.ai/openai \
    --header 'Accept: */*' \
    --header 'Connection: keep-alive' \
    --header 'Content-Type: application/json' \
    --header 'User-Agent: EchoapiRuntime/1.1.0' \
    --data '{
  "model": "openai",
  "messages": [
    {
      "role": "system",
      "content": "${systemContent}"
    },
    {
      "role": "user",
      "content": "Generate a list of 200 films ${dettagli} in JSON format. For each film, provide the original title and a description of the poster as a prompt for an LLM. Example of the content to generate: [{title: Title1 , poster : colorful poster, wikipedia : link to the Wikipedia page of the film }]. Generate only the JSON, without comments and control characters."
    }
  ],
  "seed": 42,
  "temperature": 0.9,
  "max_tokens": 10000
}'`;
  console.log('Eseguo il comando curl:');
  console.log(curlCommand);

  try {
    const result = execSync(curlCommand);
    const stringResult = result.toString();

  //  console.log('Risultato del comando curl:\n'+stringResult);
    return stringResult;
  } catch (error) {
    console.error('Errore durante l esecuzione del comando curl:', error);
    return null;
  }
}

// Funzione per estrarre il JSON dalla risposta
function extractJson(response) {
  try {
    const parsedResponse = JSON.parse(response.replaceAll('```json','').trim());
    const jsonString = parsedResponse.choices[0].message.content;
    const extractedJson = JSON.parse(jsonString);
    return extractedJson;
  } catch (error) {
    console.error('Errore nell estrazione del JSON:', error);
     console.error('******************');
      console.error(response);
      console.error('******************');
    return null;
  }
}

// Funzione per salvare il risultato in un file nella directory "movies"
function saveResultToFile(inputFilePath, result) {
  const moviesDir = path.join(__dirname, 'movies');

  // Crea la cartella "movies" se non esiste
  if (!fs.existsSync(moviesDir)) {
    fs.mkdirSync(moviesDir);
    console.log('Cartella "movies" creata.');
  }

  const baseName = path.basename(inputFilePath, path.extname(inputFilePath));
  const extName = path.extname(inputFilePath);

  let counter = 1;
  let outputFileName = `${baseName}_${counter}${extName}`;
  let outputFilePath = path.join(moviesDir, outputFileName);

  while (fs.existsSync(outputFilePath)) {
    counter++;
    outputFileName = `${baseName}_${counter}${extName}`;
    outputFilePath = path.join(moviesDir, outputFileName);
  }

  try {
    fs.writeFileSync(outputFilePath, JSON.stringify(result, null, 2));
    // Salva il JSON formattato
    console.log('Risultato salvato in:', outputFilePath);
  } catch (error) {
    console.error('Errore nel salvataggio del file:', error);
  }
}

// Main
const args = process.argv.slice(2); // Ottieni tutti gli argomenti dopo il nome dello script
const filePathIndex = args.indexOf('--file');
const filePath = filePathIndex > -1 && args[filePathIndex + 1];

const dettagliFlagIndex = args.indexOf('-D');
let dettagli = " favorites "; // Valore predefinito se -D non è specificato

if (dettagliFlagIndex > -1 && args.length > dettagliFlagIndex + 1) {
  dettagli = args[dettagliFlagIndex + 1];
}

let systemContent;

if (!filePath) {
  console.log('Nessun file JSON specificato. Utilizzo la stringa predefinita.');
  systemContent = "You are a cinema expert with encyclopedic knowledge.";
  const curlResult = executeCurlCommand(systemContent, dettagli);

  if (curlResult) {
    const extractedJson = extractJson(curlResult);
    if (extractedJson) {
     const randomFileName = `${crypto.randomBytes(16).toString('hex')}.json`;
      // Dato che non c'è un file di input, usiamo un nome predefinito per il file di output
      saveResultToFile(randomFileName, extractedJson);
    }
  }
} else {
  const fileContent = readFileContent(filePath);

  if (fileContent) {
    systemContent = fileContent.description.replaceAll('```json','').replaceAll('\'',' ').replaceAll('"',' ').trim();
    const curlResult = executeCurlCommand(systemContent, dettagli);

    if (curlResult) {
      const extractedJson = extractJson(curlResult);
      if (extractedJson) {
        saveResultToFile(filePath, extractedJson);
      }
    }
  }
}