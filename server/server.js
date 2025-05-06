const express = require('express');
const axios = require('axios');
const cheerio = require('cheerio');

const app = express();
const PORT = process.env.PORT || 3001;

// Middleware per logging delle richieste
app.use((req, res, next) => {
    console.log(`[${new Date().toISOString()}] ${req.method} ${req.url}`);
    next();
});

app.use(express.json());

// Funzione per estrarre il titolo senza anno
function extractTitleWithoutYear(title) {
    const match = title.match(/^(.*?) \(\d{4}\)$/);
    return match ? match[1].trim() : title;
}

// Funzione per cercare la locandina su Wikipedia tramite API
async function getWikipediaImageUrlFromApi(movieTitle) {
    console.log(`[API] Cercando locandina per "${movieTitle}" tramite API Wikipedia...`);
    try {
        const fetch = await import('node-fetch');
        // Aggiungo "film" alla ricerca per migliorare la pertinenza
        const searchApiUrl = `https://it.wikipedia.org/w/api.php?action=query&list=search&srsearch=${encodeURIComponent(movieTitle + ' film')}&format=json&srlimit=5`;
        const searchResponse = await fetch.default(searchApiUrl);
        if (!searchResponse.ok) {
            throw new Error(`Errore nella chiamata API di ricerca: ${searchResponse.status}`);
        }
        const searchData = await searchResponse.json();
        if (!searchData.query || !searchData.query.search || searchData.query.search.length === 0) {
            console.log(`[API] Nessun risultato trovato per "${movieTitle}".`);
            return null;
        }

        // Cerco il risultato più pertinente
        const searchResults = searchData.query.search;
        let bestMatch = null;
        let bestScore = 0;

        for (const result of searchResults) {
            const title = result.title.toLowerCase();
            const searchTitle = movieTitle.toLowerCase();
            
            // Calcolo un punteggio di pertinenza
            let score = 0;
            
            // Bonus se il titolo contiene esattamente il nome del film
            if (title.includes(searchTitle)) {
                score += 10;
            }
            
            // Bonus se il titolo inizia con il nome del film
            if (title.startsWith(searchTitle)) {
                score += 5;
            }
            
            // Bonus se il titolo contiene la parola "film"
            if (title.includes('film')) {
                score += 3;
            }
            
            // Bonus per lunghezza del titolo simile
            const lengthDiff = Math.abs(title.length - searchTitle.length);
            score += Math.max(0, 5 - lengthDiff);

            console.log(`[API] Valutazione risultato: "${result.title}" (punteggio: ${score})`);
            
            if (score > bestScore) {
                bestScore = score;
                bestMatch = result;
            }
        }

        // Se il miglior risultato ha un punteggio troppo basso, lo scarto
        if (bestScore < 5) {
            console.log(`[API] Nessun risultato sufficientemente pertinente trovato per "${movieTitle}".`);
            return null;
        }

        console.log(`[API] Miglior risultato trovato: "${bestMatch.title}" (punteggio: ${bestScore})`);
        
        const queryApiUrl = `https://it.wikipedia.org/w/api.php?action=query&prop=pageimages&pithumbsize=200&titles=${encodeURIComponent(bestMatch.title)}&format=json`;
        const queryResponse = await fetch.default(queryApiUrl);
        if (!queryResponse.ok) {
            throw new Error(`Errore nella chiamata API di query: ${queryResponse.status}`);
        }
        const queryData = await queryResponse.json();
        if (queryData.query && queryData.query.pages) {
            const pages = Object.values(queryData.query.pages);
            if (pages.length > 0 && pages[0].thumbnail && pages[0].thumbnail.source) {
                console.log(`[API] Locandina trovata per "${movieTitle}".`);
                return pages[0].thumbnail.source;
            }
        }
        console.log(`[API] Nessuna locandina trovata per "${movieTitle}".`);
        return null;
    } catch (error) {
        console.error(`[API] Errore durante l'ottenimento della miniatura per "${movieTitle}":`, error);
        return null;
    }
}

// Funzione per cercare la locandina su Wikipedia tramite scraping
async function getWikipediaImageUrl(filmTitle) {
    console.log(`[Scraping] Cercando locandina per "${filmTitle}" tramite scraping Wikipedia...`);
    const wikipediaTitle = filmTitle.replace(/ /g, '_');
    const wikipediaUrl = `https://en.wikipedia.org/wiki/${wikipediaTitle}`;
    try {
        const response = await axios.get(wikipediaUrl);
        const $ = cheerio.load(response.data);
        const imageUrl = $('.infobox img').attr('src');
        if (imageUrl) {
            console.log(`[Scraping] Locandina trovata nell'infobox per "${filmTitle}".`);
            return new URL(imageUrl, wikipediaUrl).href;
        }
        console.log(`[Scraping] Nessuna locandina trovata nell'infobox per "${filmTitle}".`);
        return await getWikipediaImageUrlFromApi(filmTitle);
    } catch (error) {
        if (error.response && error.response.status === 404) {
            console.log(`[Scraping] Pagina Wikipedia non trovata per "${filmTitle}".`);
        } else {
            console.error(`[Scraping] Errore nel recupero della pagina Wikipedia per "${filmTitle}":`, error);
        }
        return await getWikipediaImageUrlFromApi(filmTitle);
    }
}

// Funzione per scaricare l'immagine e restituirla come buffer
async function downloadImageAsBuffer(imageUrl) {
    console.log(`[Download] Scaricando immagine da "${imageUrl}"...`);
    try {
        const fetch = await import('node-fetch');
        const response = await fetch.default(imageUrl);
        if (!response.ok) {
            throw new Error(`Errore durante il download dell'immagine da "${imageUrl}": ${response.status}`);
        }
        const buffer = await response.arrayBuffer();
        console.log(`[Download] Immagine scaricata con successo.`);
        return buffer;
    } catch (error) {
        console.error(`[Download] Errore durante il download dell'immagine da "${imageUrl}":`, error);
        return null;
    }
}

// Rotta GET /locandina?titolo=...
app.get('/locandina', async (req, res) => {
    const titolo = req.query.titolo;
    if (!titolo) {
        console.log(`[Rotta] Richiesta senza titolo.`);
        return res.status(400).json({ error: 'Titolo mancante' });
    }
    console.log(`[Rotta] Richiesta locandina per "${titolo}".`);
    const cleanMovieTitle = extractTitleWithoutYear(titolo);
    console.log(`[Rotta] Titolo pulito: "${cleanMovieTitle}".`);

    try {
        const imageUrl = await getWikipediaImageUrl(cleanMovieTitle);
        if (imageUrl) {
            console.log(`[Rotta] Locandina trovata su Wikipedia: "${imageUrl}".`);
            const imageBuffer = await downloadImageAsBuffer(imageUrl);
            if (imageBuffer) {
                console.log(`[Rotta] Invio locandina come immagine JPEG.`);
                res.set('Content-Type', 'image/jpeg');
                return res.send(Buffer.from(imageBuffer));
            }
        }
        // Fallback: genera locandina AI
        console.log(`[Rotta] Nessuna locandina trovata su Wikipedia. Generazione locandina AI...`);
        const fallbackImageUrl = `https://image.pollinations.ai/prompt/${encodeURIComponent('Poster for the movie: ' + cleanMovieTitle)}?width=240&height=400&seed=628256599&model=flux&negative_prompt=worst%20quality,%20blurry`;
        const imageBuffer = await downloadImageAsBuffer(fallbackImageUrl);
        if (imageBuffer) {
            console.log(`[Rotta] Invio locandina AI come immagine JPEG.`);
            res.set('Content-Type', 'image/jpeg');
            return res.send(Buffer.from(imageBuffer));
        }
        console.log(`[Rotta] Nessuna locandina trovata.`);
        return res.status(404).json({ error: 'Locandina non trovata' });
    } catch (error) {
        console.error(`[Rotta] Errore durante la ricerca della locandina per "${cleanMovieTitle}":`, error);
        return res.status(500).json({ error: 'Errore interno del server' });
    }
});

app.listen(PORT, () => {
    console.log(`Server avviato su http://localhost:${PORT}`);
}); 