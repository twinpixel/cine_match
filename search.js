// search.js
const fs = require('node:fs/promises');
const path = require('node:path');
const axios = require('axios');
const cheerio = require('cheerio');
function extractTitleWithoutYear(title) {
     const match = title.match(/^(.*?) \(\d{4}\)$/);
     return match ? match[1].trim() : title;
 }
async function getWikipediaImageUrlFromApi(movieTitle) {
    try {
        const fetch = await import('node-fetch');

        // Step 1: Search for the Wikipedia page ID or title
        const searchApiUrl = `https://it.wikipedia.org/w/api.php?action=query&list=search&srsearch=${encodeURIComponent(movieTitle)}&format=json&srlimit=1`;
        const searchResponse = await fetch.default(searchApiUrl);
        if (!searchResponse.ok) {
            throw new Error(`Errore nella chiamata API di ricerca: ${searchResponse.status}`);
        }
        const searchData = await searchResponse.json();

        if (!searchData.query || !searchData.query.search || searchData.query.search.length === 0) {
            console.log(`Nessun risultato di ricerca trovato per "${movieTitle}" su Wikipedia.`);
            return null;
        }

        const pageTitle = searchData.query.search[0].title;

        // Step 2: Get the thumbnail URL using the page title
        const queryApiUrl = `https://it.wikipedia.org/w/api.php?action=query&prop=pageimages&pithumbsize=200&titles=${encodeURIComponent(pageTitle)}&format=json`;
        const queryResponse = await fetch.default(queryApiUrl);
        if (!queryResponse.ok) {
            throw new Error(`Errore nella chiamata API di query: ${queryResponse.status}`);
        }
        const queryData = await queryResponse.json();

        if (queryData.query && queryData.query.pages) {
            const pages = Object.values(queryData.query.pages);
            if (pages.length > 0 && pages[0].thumbnail && pages[0].thumbnail.source) {
                console.log(`Trovata per per "${movieTitle}".`);
                return pages[0].thumbnail.source;

            } else {
                //console.log(`Nessuna miniatura trovata per la pagina di "${movieTitle}" su Wikipedia.`);
                return null;
            }
        } else {
           // console.log(`Impossibile trovare le informazioni sulla pagina per "${movieTitle}" su Wikipedia.`);
            return null;
        }

    } catch (error) {
        console.error(`Errore durante l'ottenimento della miniatura per "${movieTitle}":`, error);
        return null;
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
            console.log(`Trovata nell'infobox per '${filmTitle}'.`);
            return new URL(imageUrl, wikipediaUrl).href;
        } else {
           // console.log(`Nessuna immagine trovata nell'infobox per '${filmTitle}'.`);
            // Tentativo con l'API se l'immagine nell'infobox non viene trovata
            return await getWikipediaImageUrlFromApi(filmTitle);
        }
    } catch (error) {
        if (error.response && error.response.status === 404) {
            console.log(`Pagina Wikipedia non trovata per '${filmTitle}'.`);
        } else {
           //console.error(`Errore nel recupero della pagina Wikipedia per '${filmTitle}': ${error.message}`);
        }
        return await getWikipediaImageUrlFromApi(filmTitle);
    }
}

async function downloadImage(imageUrl, filename) {
    try {
        const fetch = await import('node-fetch');
        const postersDir = path.join('assets', 'posters');
        const filePath = path.join(postersDir, filename);

        const response = await fetch.default(imageUrl);
        if (!response.ok) {
            console.error(`Errore durante il download dell'immagine da "${imageUrl}": ${response.status}`);
            return false; // Indicate failure
        }
        const buffer = await response.buffer();
        await fs.writeFile(filePath, buffer);
        console.log(`Miniatura scaricata e salvata come "${filename}".`);
        return true; // Indicate success
    } catch (error) {
        console.error(`Errore durante il download o il salvataggio dell'immagine "${filename}" da "${imageUrl}":`, error);
        return false; // Indicate failure
    }
}

function sanitizeFilename(title) {
    return title
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, '_')
        .replace('.','_')
        .replace(/^_|_$/g, ''); // Remove leading/trailing underscores
}

async function processMovies(filePath) {
    try {
        const fileContent = await fs.readFile(filePath, 'utf8');
        const movies = JSON.parse(fileContent);

        if (!Array.isArray(movies)) {
            console.error(`Il file JSON in "${filePath}" deve contenere una lista di film.`);
            return;
        }

        const assetsDir = 'assets';
        const postersDir = path.join(assetsDir, 'posters');

        try {
            await fs.access(assetsDir);
        } catch (error) {
            if (error.code === 'ENOENT') {
                await fs.mkdir(assetsDir);
            } else {
                throw error;
            }
        }

        try {
            await fs.access(postersDir);
        } catch (error) {
            if (error.code === 'ENOENT') {
                await fs.mkdir(postersDir);
            } else {
                throw error;
            }
        }

        for (const movie of movies) {
            const cleanMovieTitle = extractTitleWithoutYear(movie.title);

            if (movie && cleanMovieTitle) {
                const filename = `${sanitizeFilename(cleanMovieTitle)}.jpg`;
                const filePath = path.join(postersDir, filename);

                try {
                    await fs.access(filePath);
                    console.log(`Il file "${filename}" esiste già. API Wikipedia non interrogata.`);
                } catch (error) {
                    if (error.code === 'ENOENT') {
                        const thumbnailUrl = await getWikipediaImageUrl(cleanMovieTitle);
                        let downloadSuccess = false;
                        if (thumbnailUrl) {
                            downloadSuccess = await downloadImage(thumbnailUrl, filename);
                            console.log(`Scaricata per "${cleanMovieTitle}".`);
                        } else {
                           // console.log(`Nessuna miniatura trovata per "${cleanMovieTitle}" su Wikipedia.`);
                        }

                        if (!downloadSuccess) {
                            const fallbackImageUrl = `https://image.pollinations.ai/prompt/${encodeURIComponent('Poster for the movie: ' + cleanMovieTitle + '.  Visually, the poster should feature ' + movie.poster)}?width=240&height=400&seed=628256599&model=flux&negative_prompt=worst%20quality,%20blurry`;
                            //console.log(`Tentativo di scaricare l'immagine di fallback per "${cleanMovieTitle}" da: ${fallbackImageUrl}`);
                            const fallbackDownloadSuccess = await downloadImage(fallbackImageUrl, filename);
                            if (fallbackDownloadSuccess) {
                                console.log(`Generata per "${cleanMovieTitle}".`);
                            } else {
                                console.error(`Fallito "${cleanMovieTitle}".`);
                            }
                        }
                    } else {
                        console.error(`Errore nell'accesso al file "${filePath}":`, error);
                    }
                }
            } else {
                console.warn('Oggetto film non valido:', movie);
            }
        }
    } catch (error) {
        console.error('Errore durante la lettura o l\'elaborazione del file JSON:', error);
    }
}

async function main() {
    const moviesDir = path.join(__dirname, 'movies');

    try {
        const files = await fs.readdir(moviesDir);
        const jsonFiles = files.filter(file => path.extname(file) === '.json' && !file.endsWith('.done'));

        if (jsonFiles.length === 0) {
            console.log(`Nessun file JSON non elaborato trovato nella cartella "${moviesDir}".`);
            return;
        }

        for (const file of jsonFiles) {
            const oldFilePath = path.join(moviesDir, file);
            const newFileName = file.replace('.json', '.done');
            const newFilePath = path.join(moviesDir, newFileName);

            console.log(`Elaborazione del file: ${oldFilePath}`);
            await processMovies(oldFilePath);
            console.log(`Elaborazione completata per: ${oldFilePath}.`);

            try {
                await fs.rename(oldFilePath, newFilePath);
                console.log(`File rinominato in: ${newFilePath}`);
            } catch (renameError) {
                console.error(`Errore durante la rinomina del file "${oldFilePath}" in "${newFilePath}":`, renameError);
            }
        }

        console.log('Elaborazione di tutti i file JSON completata.');

    } catch (error) {
        if (error.code === 'ENOENT') {
            console.error(`La cartella "${moviesDir}" non esiste. Assicurati di aver eseguito prima lo script precedente.`);
        } else {
            console.error('Errore durante la lettura della cartella "movies":', error);
        }
        process.exit(1);
    }
}

main();