const fs = require('fs');
const path = require('path');
const axios = require('axios');
const cheerio = require('cheerio');

const postersDir = 'assets/posters';

function ensureDirExists(dirPath) {
  if (!fs.existsSync(dirPath)) {
    fs.mkdirSync(dirPath, { recursive: true });
  }
}

async function downloadImage(url, filename) {
  try {
    const filePath = path.join(process.cwd(), postersDir, filename);
    // Controlla se il file esiste già
    if (fs.existsSync(filePath)) {
      console.log(`Il file '${filename}' esiste già. Salto il download.`);
      return true; // Considera il download come "successo" per procedere
    }

    const response = await axios({
      url,
      responseType: 'stream',
    });
    const writer = fs.createWriteStream(filePath);

    response.data.pipe(writer);

    return new Promise((resolve, reject) => {
      writer.on('finish', resolve);
      writer.on('error', reject);
    });
  } catch (error) {
    console.error(`Errore durante il download dell'immagine da ${url}: ${error.message}`);
    return false;
  }
}

async function getWikipediaImageUrl(filmTitle) {
  const wikipediaTitle = filmTitle.replace(/ /g, '_');
  const wikipediaUrl = `https://en.wikipedia.org/wiki/${wikipediaTitle}`;
  try {
    const response = await axios.get(wikipediaUrl);
    const $ = cheerio.load(response.data);
    const imageUrl = $('.infobox img').attr('src');

    if (imageUrl) {
      return new URL(imageUrl, wikipediaUrl).href;
    } else {
      console.log(`Nessuna immagine trovata nell'infobox per '${filmTitle}'`);
      return null;
    }
  } catch (error) {
    if (error.response && error.response.status === 404) {
      console.log(`Pagina Wikipedia non trovata per '${filmTitle}'`);
    } else {
      console.error(`Errore nel recupero della pagina Wikipedia per '${filmTitle}': ${error.message}`);
    }
    return null;
  }
}

async function processFilmList(filmList) {
  for (const film of filmList) {
    const filmTitle = film.title.toLowerCase().replace(':','_').replace('\\','_').replace('/','_').replace('\'','_').replace(',','_').replace('.','_').replace('!','_').replace('à','a');
    const filmPoster = film.poster;
    console.log(`Ricerca immagine per: ${filmTitle}`);

    const filePath = path.join(process.cwd(), postersDir, filmTitle.replace(/ /g, '_') + '.jpg');
    if (!fs.existsSync(filePath)) {
      const imageUrl = await getWikipediaImageUrl(filmTitle);
      if (imageUrl) {
        const imageName = filmTitle.replace(/ /g, '_') + ".jpg";
        console.log(`Trovata immagine da Wikipedia: ${imageUrl}, download in corso come ${imageName}`);
        await downloadImage(imageUrl, imageName);
      }
    }

    if (!fs.existsSync(filePath)) {
      // Chiamata a pollination solo se il tentativo di download da Wikipedia è fallito (imageUrl è null)
      const pollinationImageUrl = `https://image.pollinations.ai/prompt/${encodeURIComponent(filmPoster)}?width=240&height=400&seed=628256599&model=flux&negative_prompt=worst%20quality,%20blurry`;
      const imageNameFallback = filmTitle.replace(/ /g, '_') + '.jpg';
      console.log(`Nessuna immagine trovata per '${filmTitle}' su Wikipedia. Tentativo con immagine generata su: ${filePath}`);
      await downloadImage(pollinationImageUrl, imageNameFallback);
    }
  }
  
}

async function main() {
  if (process.argv.length < 3) {
    console.log('Utilizzo: node script.js <percorso_file_json>');
    return;
  }

  const filePath = process.argv[2];

  try {
    ensureDirExists(postersDir);
    const fileContent = fs.readFileSync(filePath, 'utf-8');
    const filmData = JSON.parse(fileContent);

    if (!Array.isArray(filmData)) {
      console.log('Il file JSON deve contenere un array di oggetti con la chiave "title" e "poster".');
      return;
    }

    await processFilmList(filmData);
    console.log(`Processo completato. Le immagini sono state scaricate nella cartella "${postersDir}".`);
  } catch (error) {
    if (error.code === 'ENOENT') {
      console.error(`Errore: Il file '${filePath}' non è stato trovato.`);
    } else if (error instanceof SyntaxError) {
      console.error(`Errore: Il file '${filePath}' non è un file JSON valido.`);
    } else {
      console.error(`Errore durante la lettura o l'elaborazione del file JSON: ${error.message}`);
    }
  }
}
async function downloadAndConvertImage(url, filename) {
  try {
    const tempFilePath = path.join(process.cwd(), postersDir, `temp_${filename}`);
    const finalFilePath = path.join(process.cwd(), postersDir, filename.replace(/\.[^.]+$/, '') + '.png'); // Assicura l'estensione .png

    // Controlla se il file PNG esiste già
    if (fs.existsSync(finalFilePath)) {
      console.log(`Il file PNG '${finalFilePath}' esiste già. Salto il download e la conversione.`);
      return true;
    }

    // Scarica l'immagine temporaneamente
    const response = await axios({
      url,
      responseType: 'stream',
    });
    const writer = fs.createWriteStream(tempFilePath);

    response.data.pipe(writer);

    await new Promise((resolve, reject) => {
      writer.on('finish', resolve);
      writer.on('error', reject);
    });

    // Converti l'immagine in PNG usando sharp
    await sharp(tempFilePath)
      .png()
      .toFile(finalFilePath);

    // Elimina il file temporaneo
    fs.unlinkSync(tempFilePath);

    return true;
  } catch (error) {
    console.error(`Errore durante il download o la conversione dell'immagine da ${url}: ${error.message}`);
    return false;
  }
}
main();