const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

const inputDir = 'assets/personas';
const outputBaseName = 'personas';
const consolidatedMarkdownFile = path.join(inputDir, `${outputBaseName}.md`);

// Function to convert JSON data to Markdown content
function jsonToMarkdown(jsonData) {
  if (!jsonData) {
    return '# Dati mancanti o non validi';
  }

  let markdownContent = '';
  let questionsMarkdown = '';

  if (jsonData.name) {
    markdownContent += `# ${jsonData.name}\n\n`;
  }


  if (jsonData.description) {
    markdownContent += `## Descrizione\n\n${jsonData.description}\n\n`;
  }


  if (jsonData.questions && Array.isArray(jsonData.questions)) {
    questionsMarkdown += `## Domande e Risposte\n\n`;
    jsonData.questions.forEach((questionData, index) => {
      if (questionData.question) {
        questionsMarkdown += `### Domanda ${index + 1}\n\n${questionData.question}\n\n`;
      }
      if (questionData.answers && Array.isArray(questionData.answers)) {
        questionsMarkdown += `**Risposte:**\n\n`;
        questionData.answers.forEach(answer => {
          questionsMarkdown += `- ${answer}\n`;
        });
        questionsMarkdown += '\n';
      } else if (questionData.question && (!questionData.answers || !Array.isArray(questionData.answers))) {
        console.warn(`Avviso: Risposte mancanti o non valide per la domanda "${questionData.question}".`);
      } else if (!questionData.question) {
        console.warn(`Avviso: Domanda mancante nell'elemento ${index + 1} della sezione "questions".`);
      }
    });
  } else if (jsonData.questions) {
    console.warn('Avviso: La sezione "questions" non è un array o è mancante.');
  }

  return markdownContent + questionsMarkdown;
}

// Array to store the content of individual markdown files
const allMarkdownContent = [];
const indexEntries = [];

// Read files from the specified directory
fs.readdir(inputDir, (err, files) => {
  if (err) {
    if (err.code === 'ENOENT') {
      console.error(`Errore: La cartella "${inputDir}" non esiste.`);
    } else {
      console.error(`Errore durante la lettura della cartella "${inputDir}":`, err);
    }
    return;
  }

  // Filter and sort JSON files alphabetically
  const jsonFiles = files
    .filter(file => path.extname(file) === '.json')
    .sort((a, b) => a.localeCompare(b));

  const markdownFilesGenerated = [];

  Promise.all(
    jsonFiles.map(file => {
      const inputFilePath = path.join(inputDir, file);
      const outputFilePath = path.join(inputDir, path.basename(file, '.json') + '.md');
      const baseName = path.basename(file, '.json');
      markdownFilesGenerated.push(outputFilePath);

      return fs.promises.readFile(inputFilePath, 'utf8')
        .then(data => {
          try {
            const jsonData = JSON.parse(data);
            const markdownContent = jsonToMarkdown(jsonData);
            const name = jsonData.name || baseName;
            indexEntries.push(`- [${name}](#${name.toLowerCase().replace(/ /g, '-')})`);
            return fs.promises.writeFile(outputFilePath, markdownContent, 'utf8')
              .then(() => {
                console.log(`File "${outputFilePath}" creato con successo.`);
                allMarkdownContent.push(markdownContent);
              })
              .catch(writeErr => {
                console.error(`Errore durante la scrittura del file "${outputFilePath}":`, writeErr);
              });
          } catch (parseErr) {
            console.error(`Errore durante l'analisi JSON del file "${inputFilePath}":`, parseErr);
          }
        })
        .catch(readErr => {
          console.error(`Errore durante la lettura del file "${inputFilePath}":`, readErr);
        });
    })
  ).then(() => {
    // Create the index content
    const indexMarkdown = `# Indice\n\n${indexEntries.join('\n')}\n\n---\n\n`;

    // Concatenate the index with all generated markdown files
    const finalMarkdownContent = indexMarkdown + allMarkdownContent.join('\n\n---\n\n');

    fs.writeFile(consolidatedMarkdownFile, finalMarkdownContent, 'utf8', (err) => {
      if (err) {
        console.error(`Errore durante la scrittura del file consolidato "${consolidatedMarkdownFile}":`, err);
        return;
      }
      console.log(`File consolidato "${consolidatedMarkdownFile}" creato con successo.`);

      // Attempt to convert to different formats using pandoc
      const formats = ['html', 'pdf', 'docx'];
      const conversions = {};

      formats.forEach(format => {
        const outputFile = path.join(inputDir, `${outputBaseName}.${format}`);
        console.log(`Tentativo di conversione a ${format}...`);
        const pandoc = spawn('pandoc', [consolidatedMarkdownFile, '-o', outputFile]);

        let stderrOutput = '';

        pandoc.stderr.on('data', (data) => {
          stderrOutput += data.toString();
        });

        pandoc.on('close', (code) => {
          if (code === 0) {
            console.log(`Conversione a ${format} completata con successo: "${outputFile}"`);
            conversions[format] = 'success';
          } else {
            console.error(`Errore durante la conversione a ${format}:`, stderrOutput);
            conversions[format] = 'failed';
          }
        });

        pandoc.on('error', (err) => {
          console.error(`Errore durante l'esecuzione di pandoc per ${format}:`, err);
          conversions[format] = 'failed';
        });
      });
    });
  });
});