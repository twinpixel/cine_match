import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:cine_match/firebase_options.dart';
import 'package:image/image.dart' as img;
import 'package:cached_network_image/cached_network_image.dart'; // Importa il package
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart'; // Import path_provider
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_html/html.dart' as html;
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_vertexai/firebase_vertexai.dart';


var critico = '01';
var model;
const numeroCritici = 8;
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initFirebase();
  await _QuizPageState.loadReceivedTitles(); // Carica i titoli salvati

  runApp(const MyApp());
}

Future<void> initFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print('Errore  $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CineMatch',
      theme: ThemeData(
        iconTheme: IconThemeData(
          color: Colors.amber.shade600,
          size: 40,
        ),
        colorScheme: ColorScheme.dark(
          primary: Colors.red.shade900,
          secondary: Colors.amber.shade600,
          surface: const Color(0xFF2A2A2A),
          onPrimary: Colors.white,
        ),
        useMaterial3: true,
        textTheme: TextTheme(
          displayLarge: TextStyle(
            fontFamily: 'Vintage',
            fontSize: 32,
            color: Colors.amber.shade600,
          ),
          bodyLarge: const TextStyle(color: Colors.white70),
          bodyMedium: TextStyle(
            color: Colors.grey.shade400,
            height: 1.4,
          ),
        ),
        cardTheme: CardTheme(
          color: const Color(0xFF1E1E1E),
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: Colors.red.shade900, width: 1),
          ),
        ),
      ),
      home: const ImageSelectionScreen(),
    );
  }
}

class ImageSelectionScreen extends StatefulWidget {
  const ImageSelectionScreen({super.key});

  @override
  State<ImageSelectionScreen> createState() => _ImageSelectionScreenState();
}

class _ImageSelectionScreenState extends State<ImageSelectionScreen> {
  String? _selectedImageNumber;
  late Future<List<String>>
      _imageDescriptionsFuture; // Nuovo Future per le descrizioni
  void _navigateToQuiz() {
    if (_selectedImageNumber != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => QuizPage(selectedImage: _selectedImageNumber!),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    initFirebase().then((value) {
      model = FirebaseVertexAI.instance.generativeModel(
        model: 'gemini-2.0-flash',
      );
    });
    _imageDescriptionsFuture = _loadImageDescriptions();
  }

  Future<List<String>> _loadImageDescriptions() async {
    List<String> descriptions = [];
    for (int i = 1; i <= numeroCritici; i++) {
      final fileNumber = i.toString().padLeft(2, '0');
      try {
        final jsonData = await getPErsonaData(fileNumber);
        descriptions
            .add(jsonData['description'] ?? 'Descrizione non disponibile');
      } catch (e) {
        print('Errore nel caricamento del persona $fileNumber: $e');
        descriptions.add('Descrizione non disponibile');
      }
    }
    return descriptions;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<String>>(
        future: _imageDescriptionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingIndicator();
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return _buildErrorState();
          }

          final descriptions = snapshot.data!;
          return _buildMainContent(descriptions);
        },
      ),
    );
  }

  Widget _buildMainContent(List<String> descriptions) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: numeroCritici,
            itemBuilder: (context, index) {
              final imageNumber = (index + 1).toString().padLeft(2, '0');
              final imagePath = 'assets/images/$imageNumber.png';
              return LayoutBuilder(builder: (context, constraints) {
                final isSmallScreen = constraints.maxWidth < 400;
                return Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                        color: _selectedImageNumber == imageNumber
                            ? Colors.amber.shade600
                            : Colors.transparent,
                        width: 2),
                  ),
                  child: InkWell(
                    onTap: () {
                      critico = imageNumber;
                      setState(() => _selectedImageNumber = imageNumber);
                      _navigateToQuiz();
                    },
                    child: isSmallScreen
                        ? _buildVerticalLayout(imagePath, index, descriptions)
                        : _buildHorizontalLayout(
                            imagePath, index, descriptions),
                  ),
                );
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHorizontalLayout(
      String imagePath, int index, List<String> descriptions) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Immagine rimane uguale
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 6,
                    spreadRadius: 2)
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(imagePath, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                descriptions[index], // Usa la descrizione dal JSON
                style: const TextStyle(
                    color: Colors.white70, fontSize: 14, height: 1.35),
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalLayout(
      String imagePath, int index, List<String> descriptions) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Immagine rimane uguale
          Container(
            height: 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 6,
                    spreadRadius: 2)
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(imagePath, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            descriptions[index], // Usa la descrizione dal JSON
            style: const TextStyle(
                color: Colors.white70, fontSize: 14, height: 1.35),
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container();
  }

  Widget _buildErrorState() {
    return Container();
  }
}

class QuizPage extends StatefulWidget {
  final String selectedImage; // Ora contiene solo '01', '02'...
  const QuizPage({super.key, required this.selectedImage});

  @override
  State createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  static List<String> _receivedTitles = [];

  List<Question> _questions = [];
  int _currentQuestionIndex = 0;
  String? _selectedAnswer;
  String? _savedQuestion;
  String? _savedAnswer;
  bool _isLoading = false;
  final String _loadingMessage = "";
  final List<Map<String, String>> _answers = [];

  static const String _storageKey = 'saved_questions';
  late SharedPreferences _prefs; // Aggiungi questa linea
  String? _selectedImage;
// All'interno della classe _QuizPageState
  static Future<void> loadReceivedTitles() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _receivedTitles = prefs.getStringList('receivedTitles') ?? [];
    print('Loaded from cache: $_receivedTitles');
  }

  static Future<void> saveReceivedTitles() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('receivedTitles', _receivedTitles);
  }

  @override
  void initState() {
    super.initState();
    _selectedImage = widget.selectedImage;
    _fetchQuestions();
  }

  Future<void> _fetchQuestions() async {
    setState(() => _isLoading = true);

    try {
      final String personaJson = await _loadPersonaJson(widget.selectedImage);
      final Map<String, dynamic> personaData = jsonDecode(personaJson);

      // Estrazione delle domande dal JSON del persona
      final List<dynamic> questionsJson = personaData['questions'] ?? [];

      // Debug: stampa il numero di domande caricate
      //print('Caricate ${questionsJson.length} domande dal JSON del persona');

      final List<Question> allQuestions = questionsJson
          .map((json) => Question.fromJson(json as Map<String, dynamic>))
          .toList();

      setState(() {
        _questions = _getRandomQuestions(allQuestions, 5);
        //print('Selezionate ${_questions.length} domande casuali');
      });
    } catch (error) {
      print('Errore CRITICO: $error');
      setState(() {
        _questions = _createFallbackQuestions();
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

// Funzione di fallback per emergenze
  List<Question> _createFallbackQuestions() {
    return [
      Question(
          question: "Qual è il tuo genere cinematografico preferito?",
          answers: ["Azione", "Commedia", "Drammatico", "Fantascienza"]),
      Question(
          question: "Che tipo di finale preferisci?",
          answers: ["Felice", "Aperto", "Tragico", "A sorpresa"])
    ];
  }

  List<Question> _getRandomQuestions(List<Question> allQuestions, int count) {
    final shuffled = List<Question>.from(allQuestions)..shuffle();
    return shuffled.take(count).toList();
  }

  void _selectAnswer(String answer) {
    setState(() {
      _selectedAnswer = answer;
      _savedQuestion = _questions[_currentQuestionIndex].question;
      _savedAnswer = answer;
      _answers.add({
        'question': _savedQuestion!,
        'answer': _savedAnswer!,
      });
      if (_currentQuestionIndex < _questions.length - 1) {
        _currentQuestionIndex++;
        _selectedAnswer = null;
      } else {
        _fetchRecommendations(context, _answers);
      }
    });
  }

  Future<void> _fetchRecommendations(
      BuildContext context, List<Map<String, String>> answers) async {
    _showLoadingScreen(context);

    try {
      final String prompt = await _buildRecommendationPrompt(answers);
      final String role = await _buildRecommendationRole();
      List<dynamic> movieList = [];
      if (movieList.isEmpty || movieList.length < 4) {
        //print('Asking gemini:...');
        List<dynamic> movieList2 = await askGemini(role + prompt);
        movieList.addAll(movieList2);
      }

      if (movieList.isEmpty || movieList.length < 4) {
        //print('Asking mistral:...');
        List<dynamic> movieList2 = await askMistral(role, prompt);
        movieList.addAll(movieList2);
      }
      if (movieList.isEmpty || movieList.length < 4) {
        //print('Asking pollination:...');
        List<dynamic> movieList2 = await askPollination(role, prompt);
        movieList.addAll(movieList2);
      }
      //print('$movieList');

      _navigateToMovieList(context, movieList);
    } catch (e) {
      _handleRecommendationError(context, e);
    }
  }

  Future<List<dynamic>> askPollination(String role, String prompt) async {
    try {
      final url = Uri.parse('https://text.pollinations.ai/openai');
      final headers = {
        'Content-Type': 'application/json',
      };
      final body = jsonEncode({
        "model": "openai",
        "messages": [
          {"role": "system", "content": role},
          {"role": "user", "content": prompt}
        ],
        "seed": 42,
        "temperature": 0.7,
        "max_tokens": 8000
      });
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        final responseJson = jsonDecode(response.body);

        // Estrae il contenuto dalla risposta
        final content =
            responseJson['choices'][0]['message']['content'] as String;

        // Pulisce il testo rimuovendo i markdown code blocks
        final cleanedContent =
            content.replaceAll('```json', '').replaceAll('```', '').trim();

        // Parsing del JSON
        final movieList = jsonDecode(cleanedContent) as List<dynamic>;

        return movieList;
      } else {
        print('Errore nella risposta: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Errore durante la richiesta a Pollinations: $e');
      return [];
    }
  }

  Future<List<dynamic>> askMistral(String role, String prompt) async {
    try {
      const keyMistral = String.fromEnvironment('KEY_MISTRAL');
      if (keyMistral.isEmpty) {
        throw AssertionError('KEY_MISTRAL is not set');
      }

      final url = Uri.parse('https://api.mistral.ai/v1/chat/completions');
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $keyMistral',
      };

      final body = jsonEncode({
        "model": "mistral-small-latest",
        "messages": [
          {"role": "system", "content": role},
          {"role": "user", "content": prompt}
        ],
        "temperature": 0.7,
        "max_tokens": 8000
      });

      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final responseJson = jsonDecode(response.body);
        final content =
            responseJson['choices'][0]['message']['content'] as String;
        //print('content: $content');
        final cleanedContent = content
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .replaceAll('Ã³', 'ò')
            .replaceAll('Ã¨', 'è')
            .replaceAll('Ã©', 'é')
            .replaceAll('Ã', 'È')
            .replaceAll('Ã ', 'à ')
            .replaceAll('Ã.', 'à.')
            .replaceAll('Ã', 'à')
            .replaceAll('Ã¹', 'ù')
            .trim();

        final movieList = jsonDecode(cleanedContent) as List<dynamic>;

        return movieList;
      } else {
        print(
            'Errore nella risposta: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('Errore durante la richiesta a Mistral: $e');
      return [];
    }
  }

  Future<List<dynamic>> askGemini(String prompt) async {
    try {
      final promptG = [Content.text(prompt)];
      final responseAI = await model.generateContent(promptG);
      final List<dynamic> movieList =
          processResponseText(responseAI.text.toString());
      return movieList;
    } catch (e) {
      print('Errore durante la richiesta a Gemini: $e');
      return [];
    }
  }

  void _showLoadingScreen(BuildContext context) {
    final message = _getRandomInspirationalMessage();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          body: _buildLoadingScreenBody(message),
        ),
      ),
    );
  }

  String _getRandomInspirationalMessage() {
    const List<String> inspirationalMessages = [
      "Accendiamo i proiettori...🍿",
      "Scegliendo la colonna sonora perfetta...🎬",
      "Allestiamo il tuo divano cinematografico...🍿",
      "Controlliamo la lista degli Oscar...🎬",
      "Preparando i popcorn... 🍿",
      "Regolazione della luce ambientale...🎬",
      "Selezionando da film cult a nuove uscite...🍿",
      "Reticulating splines...🎬",
      "Calibrazione volume anti-vicini...🔇",
      "Scongelamento pellicola vintage...🎞️",
      "Ottimizzazione angolo cuscino...🛋️",
      "Ricarica batterie telecomando...🔋",
      "Download effetti speciali...💥",
      "Allineamento stelle del cinema...🌟",
      "Ricerca sottotitoli sgrammaticati...🤌",
      "All your base are belong to us...📺",
      "Deframmentazione hard disk emotivo...💾",
      "Installazione pacchetto lacrime per drammi...😭",
      "Formattazione pregiudizi sui musical...🕺",
      "Ottimizza-azione del divano...⚡",
      "Controllo scorte di tisana serale...☕",
      "Rendering della perfetta inquadratura...🎥"
    ];

    return inspirationalMessages[
        Random().nextInt(inspirationalMessages.length)];
  }

  Widget _buildLoadingScreenBody(String message) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: _createLoadingScreenDecoration(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: Image.asset(
                  'assets/videos/wait3.gif',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          _buildLoadingMessage(message),
        ],
      ),
    );
  }

  BoxDecoration _createLoadingScreenDecoration() {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.black.withOpacity(0.9),
          const Color(0xFF1A1A1A),
        ],
        stops: const [0.3, 1.0],
      ),
    );
  }

  Widget _buildLoadingMessage(String message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5.0),
      child: Text(
        message,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.amber.shade600,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 10,
            )
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Future<String> _buildRecommendationPrompt(
      List<Map<String, String>> answers) async {
    final String summary = answers
        .map((answer) =>
            'Domanda: ${answer['question']}\nRisposta: ${answer['answer']}\n')
        .join();
    final String fileNumber = widget.selectedImage;
    Map<String, dynamic> personaData = await getPErsonaData(fileNumber);
    String postContent = personaData['post'] ?? '';
    String exampleContent = _defaultExampleContent();
    postContent = postContent.isNotEmpty ? postContent : _defaultPostContent();
    if (_receivedTitles.length > 100) _receivedTitles.removeRange(0, 5);
    String exclusionInstruction = _receivedTitles.isNotEmpty
        ? "\nEscludi ASSOLUTAMENTE questi film: ${_receivedTitles.join(', ')}.\n"
        : "";
    final special = "\n.Produci in ogni caso almeno 4 risultati\n"
        "$exclusionInstruction"
        "Aggiungi anche un film che non c'entra e giustificane la scelta nel campo \"why_recomended\".\n"
        "Ordina i risultati in ordine decrescente di score.\n"
        "Includi solo film realmente esistenti.\n"
        "Usa il corretto encoding per le lettere accentate e i carateri speciali per la lingua italiana."
        "***IMPORTANTE*** PRODUCI IN OGNI CASO UN JSON VALIDO. Verifica il risultato due volte. ";

    const jsonDesc =
        "Output JSON\n'poster_prompt':'Breve descrizione per LLM che dovrà generare la locandina',\n"
        "Genera un array JSON con le seguenti informazioni per ciascun film:,\n"
        "'title': Titolo del film nella edizione italiana,\n"
        "'english_title': Titolo orginale del film\n"
        "'wikipedia': Link corretto alla pagina wikipedia del film,\n"
        "'description': Brevissima sinossi del film, in tono formale e distaccato. molto breve. Se possibile in una frase,\n"
        "'score': punteggio che indica quanto il film è vicino ai gusti dell'utente in una scala da 1 a 10,\n"
        "'genre': un solo genere  a cui appartiene il film scelto tra [action, horror, adventure,musical, comedy ,science-fiction ,crime ,war ,drama ,western, historical]\n";

    final res =
        "\n$summary\n$jsonDesc\n$postContent$exampleContent\n\n$special";
    //print('Prompt:\n $res');
    return res;
  }

  Future<String> _buildRecommendationRole() async {
    final String fileNumber = widget.selectedImage;
    Map<String, dynamic> personaData = await getPErsonaData(fileNumber);

    // Estrazione dei contenuti dal JSON
    String preContent = personaData['pre'] ?? '';

    preContent = preContent.isNotEmpty ? preContent : _defaultPreContent();

    final res = "$preContent\n";
    return res;
  }

  String _defaultPreContent() =>
      "Sei un esperto critico cinematografico. In base alle seguenti risposte consiglia 5 film all'utente"; // Mantieni il vecchio contenuto
  String _defaultPostContent() => "Cerca di evitare film troppo comuni.";

  String _defaultExampleContent() =>
      "\nEcco un esempio di struttura JSON desiderata:\n"
      "```json\n"
      "[\n"
      " {\n"
      " \"wikipedia\": \"https://it.wikipedia.org/wiki/Forrest_Gump\",\n"
      " \"title\": \"Forrest Gump\",\n"
      " \"english_title\": \"Forrest Gump\",\n"
      " \"description\": \"La vita di Forrest Gump, un uomo con un basso quoziente intellettivo, ma con un cuore grande e una capacità straordinaria di trovarsi al centro di eventi storici.\",\n"
      " \"awards\": \"Oscar come miglir film\",\n"
      " \"why_recommended\": \"Film tocccante e sorprendente\",\n"
      "\"score\": 7,\n"
      " \"genre\": \"drama\",\n"
      "\"poster_prompt\":\"Descrizione per LLM che dovrà generare la locandina\"\n"
      " },\n"
      " ...\n"
      "]\n"
      "***ISTRUZIONI SPECIALI:  deve essere prodotto solo il json finale, senza altri comenti senza carateri speciali e apici o doppi apici";

  Future<String> _loadAssetFile(String path) async {
    try {
      return await rootBundle.loadString(path);
    } catch (e) {
      print('Errore nel caricamento del file $path: $e');
      return '';
    }
  }

  processResponseText(String contentText) {
    final jsonString = contentText
        .replaceAll('``````', '')
        .replaceAll('```json', '')
        .replaceAll('```', '');

    final movieList = jsonDecode(jsonString);

    // Aggiungi i titoli al set
    for (final movie in movieList) {
      final title = movie['title']?.toString();
      if (title != null && title.isNotEmpty) {
        _receivedTitles.add(title);
      }
    }
    if (_receivedTitles.length > 100) {
      _receivedTitles.removeRange(0, 10);
    }
    _QuizPageState.saveReceivedTitles(); // Salva dopo l'aggiornamento

    //print('Titoli memorizzati: $_receivedTitles'); // Debug

    return movieList;
  }

  void _navigateToMovieList(BuildContext context, List<dynamic> movieList) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => MovieListPage(
            movies: movieList,
            selectedImage: widget.selectedImage // Aggiungi questo
            ),
      ),
    );
  }

  void _handleRecommendationError(BuildContext context, dynamic error) {
    print('Errore durante la generazione delle raccomandazioni: $error');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Errore nel generare raccomandazioni.')),
    );

    Navigator.pop(context); // Torna alla schermata precedente
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          _buildBackground(),
          _buildMainContent(),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      title: FutureBuilder<Map<String, dynamic>>(
          future: getPErsonaData(widget.selectedImage),
          builder: (context, snapshot) {
            final name = snapshot.hasData
                ? snapshot.data!['name'] ?? 'Critico'
                : 'Critico';

            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.amber.shade600,
                      width: 1.5,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.asset(
                      'assets/images/${widget.selectedImage}.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: Colors.amber.shade600,
                        fontFamily: 'Vintage',
                        fontSize: 20,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.psychology_rounded,
                      color: Colors.amber.shade600,
                      size: 28,
                    ),
                  ],
                ),
              ],
            );
          }),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: const AssetImage('assets/images/background.png'),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.7),
            BlendMode.darken,
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Center(
      child: _isLoading
          ? _buildInitialLoading()
          : _questions.isEmpty
              ? const Text('Nessuna domanda disponibile')
              : _buildQuestionnaire(),
    );
  }

  Widget _buildInitialLoading() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildAnimatedLoader(),
        const SizedBox(height: 20),
        _buildLoadingMessage2(),
      ],
    );
  }

  Widget _buildAnimatedLoader() {
    return SizedBox(
      width: 200,
      height: 200,
      child: Image.asset(
        'assets/videos/wait3.gif',
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildLoadingMessage2() {
    return Text(
      "Stop scrolling, start watching",
      style: TextStyle(
        fontSize: 16,
        color: Colors.amber.shade600,
        fontWeight: FontWeight.w500,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildQuestionnaire() {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildQuestionCard(),
          const SizedBox(height: 20),
          ..._buildAnswerButtons(),
        ],
      ),
    );
  }

  Widget _buildQuestionCard() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: _questionCardDecoration(),
      child: _buildQuestionText(),
    );
  }

  BoxDecoration _questionCardDecoration() {
    return BoxDecoration(
      color: Colors.black.withOpacity(0.6),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: Colors.amber.shade600.withOpacity(0.8),
        width: 2,
      ),
    );
  }

  Widget _buildQuestionText() {
    return Text(
      _questions[_currentQuestionIndex].question,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.amber.shade100,
        shadows: [
          Shadow(
            color: Colors.black.withOpacity(0.8),
            blurRadius: 10,
          )
        ],
      ),
      textAlign: TextAlign.center,
    );
  }

  List<Widget> _buildAnswerButtons() {
    return _questions[_currentQuestionIndex].answers.map((answer) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 32.0),
        child: _buildAnswerButton(answer),
      );
    }).toList();
  }

  Widget _buildAnswerButton(String answer) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 60),
      decoration: _answerButtonDecoration(),
      child: ElevatedButton(
        style: _answerButtonStyle(),
        onPressed: () => _selectAnswer(answer),
        child: _buildAnswerButtonText(answer),
      ),
    );
  }

  BoxDecoration _answerButtonDecoration() {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(15),
      boxShadow: [
        BoxShadow(
          color: Colors.amber.withOpacity(0.2),
          blurRadius: 8,
          spreadRadius: 1,
        )
      ],
      gradient: LinearGradient(
        colors: [
          Colors.red.shade900.withOpacity(0.6),
          Colors.red.shade800.withOpacity(0.7),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    );
  }

  ButtonStyle _answerButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: Colors.transparent,
      shadowColor: Colors.transparent,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      minimumSize: const Size.fromHeight(0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
    );
  }

  Widget _buildAnswerButtonText(String answer) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        answer,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.amber.shade100,
          height: 1.2,
        ),
        textAlign: TextAlign.center,
        softWrap: true,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black,
      child: Column(
        children: [
          Expanded(child: _buildFullScreenLoader()),
          _buildBottomLoadingMessage(),
        ],
      ),
    );
  }

  Widget _buildFullScreenLoader() {
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: Image.asset(
        'assets/videos/wait3.gif',
        fit: BoxFit.fitHeight,
        filterQuality: FilterQuality.high,
      ),
    );
  }

  Widget _buildBottomLoadingMessage() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 40.0),
      child: Text(
        "Stop scrolling, start watching",
        style: TextStyle(
          fontSize: 18,
          color: Colors.amber.shade600,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.8),
              blurRadius: 10,
              offset: const Offset(2, 2),
            )
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class MovieListPage extends StatelessWidget {
  final List<dynamic> movies;
  final String selectedImage;

  const MovieListPage(
      {super.key, required this.movies, required this.selectedImage});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _restartApp(context);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center, // Centra l'intera riga
            children: [
              // Immagine del critico
              Container(
                width: 40,
                height: 40,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade600, width: 1.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.asset(
                    'assets/images/$critico.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              // Testo e icona
              Row(
                mainAxisSize:
                    MainAxisSize.min, // Impedisce l'espansione eccessiva
                children: [
                  Text(
                    'Oggi ti consiglio: ',
                    style: TextStyle(
                      color: Colors.amber.shade600,
                      fontFamily: 'Vintage',
                      fontSize: 20,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.local_movies_rounded,
                      color: Colors.amber.shade600, size: 28),
                ],
              ),
            ],
          ),
          leading: Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: IconButton(
              icon: Icon(Icons.replay_circle_filled_rounded,
                  size: 30, color: Colors.amber.shade600),
              onPressed: () => _restartApp(context),
              tooltip: 'Ricomincia',
            ),
          ),
        ),
        body: ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: movies.length,
          itemBuilder: (context, index) => _buildMovieItem(context, index),
        ),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      title: const Text('Film Consigliati'),
      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => _restartApp(context),
      ),
    );
  }

  Widget _buildMovieItem(BuildContext context, int index) {
    final movie = movies[index];
    return InkWell(
      onTap: () => _handleMovieTap(context, movie),
      borderRadius: BorderRadius.circular(12.0),
      child: _buildMovieCard(context, movie),
    );
  }

  Card _buildMovieCard(BuildContext context, dynamic movie) {
    final score = movie['score']?.toDouble() ?? 0.0;

    return Card(
      elevation: 12,
      margin: const EdgeInsets.only(bottom: 24),
      shape: _cardShape(),
      child: Container(
        decoration: _cardDecoration(),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Prima riga: Titolo e score
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          movie['title'] ?? 'Titolo non disponibile',
                          style: TextStyle(
                            fontSize: 24,
                            color: Colors.amber.shade400,
                            letterSpacing: 1.5,
                            shadows: [
                              Shadow(
                                color: Colors.red.shade900.withOpacity(0.7),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        if (movie['year'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              '(${movie['year']})',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.amber.shade600,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  _buildScoreIndicator(score),
                ],
              ),

              const SizedBox(height: 16),

              // Seconda riga: Locandina e descrizione
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Locandina a sinistra
                  _buildPosterSection(movie),

                  const SizedBox(width: 16),

                  // Descrizione
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Text(
                        movie['description'] ?? 'Descrizione non disponibile',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.amber.shade100,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Separatore prima del why_recommended
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.amber.shade600.withOpacity(0.3),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Why recommended
              if (movie['why_recommended'] != null &&
                  movie['why_recommended'].isNotEmpty)
                Text(
                  movie['why_recommended'],
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.amber.shade100,
                    height: 1.4,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  RoundedRectangleBorder _cardShape() {
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(
        color: Colors.amber.shade600.withOpacity(0.8),
        width: 1.2,
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF1A1A1A), Color(0xFF2D2D2D)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.red.shade900.withOpacity(0.4),
          blurRadius: 15,
          spreadRadius: 2,
          offset: const Offset(0, 4),
        )
      ],
    );
  }

  Widget _buildMovieTitle(dynamic movie) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          movie['title'] ?? 'Titolo non disponibile',
          style: TextStyle(
            fontSize: 24,
            color: Colors.amber.shade400,
            letterSpacing: 1.5,
            shadows: [
              Shadow(
                color: Colors.red.shade900.withOpacity(0.7),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        if (movie['year'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              '(${movie['year']})',
              style: TextStyle(
                fontSize: 14,
                color: Colors.amber.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildScoreIndicator(double score) {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 50,
          height: 50,
          child: CircularProgressIndicator(
            value: score / 10,
            backgroundColor: Colors.grey.shade800,
            valueColor: AlwaysStoppedAnimation<Color>(
              _getScoreColor(score),
            ),
            strokeWidth: 4,
            strokeCap: StrokeCap.round,
          ),
        ),
        ShaderMask(
          shaderCallback: (Rect bounds) {
            return LinearGradient(
              colors: [
                Colors.amber.shade300,
                Colors.amber.shade600,
              ],
              stops: const [0.3, 1.0],
            ).createShader(bounds);
          },
          child: Text(
            '${score.toInt()}',
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Courier',
                letterSpacing: 1.5),
          ),
        ),
      ],
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 8) return Colors.green.shade400;
    if (score >= 6) return Colors.amber.shade600;
    return Colors.red.shade400;
  }

  Widget _buildMovieContentRow(dynamic movie) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPosterSection(movie),
        const SizedBox(width: 16),
        Expanded(child: _buildMovieInfoSection(movie)),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildPosterSection(dynamic movie) {
    return Container(
      width: 110,
      height: 160,
      decoration: _posterDecoration(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: buildPosterWeb(movies.indexOf(movie), movie),
      ),
    );
  }

  BoxDecoration _posterDecoration() {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.6),
          blurRadius: 10,
          spreadRadius: 2,
        )
      ],
    );
  }

  Widget _buildMovieInfoSection(dynamic movie) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (movie['why_recommended'] != null &&
            movie['why_recommended'].isNotEmpty)
          Text(
            movie['why_recommended'],
            style: TextStyle(
              fontSize: 14,
              color: Colors.amber.shade100,
              height: 1.4,
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 2,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            Colors.amber.shade600.withOpacity(0.5),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  void _handleMovieTap(BuildContext context, dynamic movie) async {
    final String movieLink =
        "https://www.google.com/search?q=streaming+film+${movie['title']}+-+${movie['english_title']}";
    try {
      final Uri uri = Uri.parse(movieLink);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalNonBrowserApplication,
          webOnlyWindowName: '_blank',
          webViewConfiguration:
              const WebViewConfiguration(enableJavaScript: true),
        );
      } else {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } on PlatformException catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Errore: ${e.message}')));
    }
  }

  void _restartApp(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const ImageSelectionScreen()),
      (route) => false,
    );
  }
}

class _CachedImageLoader extends StatelessWidget {
  final String imageUrl;
  final int? placeholderIndex;

  const _CachedImageLoader({
    required this.imageUrl,
    this.placeholderIndex,
  });

  @override
  Widget build(BuildContext context) {
    if (_shouldUseWebPlaceholder) {
      return _buildWebPlaceholder();
    }
    return _buildNetworkImage();
  }

  // Controllo condizione per placeholder web
  bool get _shouldUseWebPlaceholder => kIsWeb && placeholderIndex != null;

  // Costruzione placeholder per web
  Widget _buildWebPlaceholder() {
    final calculatedIndex = (placeholderIndex! % 5) + 1;
    return placeHolderImage("X");
  }

  // Costruzione immagine con caching
  Widget _buildNetworkImage() {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      imageBuilder: _imageBuilder,
      placeholder: _loadingPlaceholder,
      errorWidget: _errorPlaceholder,
      fadeInDuration: const Duration(milliseconds: 10),
      fadeOutDuration: Duration.zero,
    );
  }

  // Builder per l'immagine caricata
  Widget _imageBuilder(BuildContext context, ImageProvider imageProvider) {
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: imageProvider,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  // Placeholder durante il loading
  Widget _loadingPlaceholder(BuildContext context, String url) {
    return _defaultPlaceholder();
  }

  // Placeholder per errori
  Widget _errorPlaceholder(BuildContext context, String url, dynamic error) {
    return _defaultPlaceholder();
  }

  // Placeholder generico di default
  Widget _defaultPlaceholder() {
    return placeHolderImage("X");
  }
}

Future<String> _getWikipediaImageUrl(String? wikipediaUrl) async {
  try {
    final response = await http.get(Uri.parse(wikipediaUrl!));
    if (response.statusCode == 200) {
      dom.Document document = html_parser.parse(response.body);
      dom.Element? imageElement = document.querySelector('.infobox img');

      if (imageElement != null) {
        String? imageUrl = imageElement.attributes['src'];
        if (imageUrl != null) {
          if (imageUrl.startsWith('//')) {
            return 'https:$imageUrl';
          }
          return imageUrl;
        }
      }
    }
  } catch (e) {
    print('Errore scraping Wikipedia: $e');
  }
  return '';
}

Future<String> _getMoviePosterUrl(String? wikipediaUrl) async {
  try {
    // Fallback a Wikipedia
    if (wikipediaUrl != null && wikipediaUrl.isNotEmpty && !(kIsWeb)) {
      final String wikipediaImage = await _getWikipediaImageUrl(wikipediaUrl);
      if (wikipediaImage.isNotEmpty) {
        return wikipediaImage;
      }
    }

    return "";
  } catch (e) {
    print('Errore durante lo scraping combinato: $e');
    return "";
  }
}

class Question {
  final String question;
  final List<String> answers;

  Question({required this.question, required this.answers});

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      question: json['question'] as String,
      answers: List<String>.from(json['answers']),
    );
  }
}

final Set<String> _failedImageTitles = {};
Future<Widget?> loadCheap(String movieTitle, String posterPrompt) async {
  try {
    final encodedPrompt = Uri.encodeComponent(posterPrompt);
    final url = "https://image.pollinations.ai/prompt/$encodedPrompt"
        "?width=240&height=400&seed=628256599"
        "&model=flux&negative_prompt=worst%20quality,%20blurry";

    final response = await http.get(
      Uri.parse(url),
      headers: {'Accept': 'image/jpeg'},
    ).timeout(const Duration(seconds: 5));

    if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
      //print('LoadCheap per $movieTitle');
      final bytes = response.bodyBytes;
      await saveImageToCache(movieTitle, bytes);
      return Image.memory(bytes, fit: BoxFit.cover);
    }
  } catch (e) {
    _failedImageTitles.add(movieTitle);
    print('Errore loadCheap per $movieTitle: $e');
  }
  return null;
}

Future<Widget> generateImage(
    String movieTitle, String posterPrompt, String genre) async {
  if (_failedImageTitles.contains(movieTitle)) {
    return placeHolderImage(movieTitle, genre);
  }
  try {
    final cachedImage = await loadFromCache(movieTitle);
    if (cachedImage != null) {
      //print('Immagine ottenuta dalla cache per: $movieTitle');
      return cachedImage;
    }
    final cheapImage = await loadCheap(movieTitle, posterPrompt);
    if (cheapImage != null) {
      //print('Immagine ottenuta tramite loadCheap per: $movieTitle');
      return cheapImage;
    }
    return placeHolderImage(movieTitle, genre);
  } catch (e) {
    _failedImageTitles.add(movieTitle);
    //print('Exception generando immagine per: $movieTitle - $e');
    return placeHolderImage(movieTitle, genre);
  }
}

Image placeHolderImage(String movieTitle, [String? genre]) {
  if (genre != null && genre.isNotEmpty) {
    return Image.asset(
      'assets/genres/${genre.toLowerCase()}.jpg',
      fit: BoxFit.cover,
    );
  } else {
    return Image.asset('assets/genres/genre.jpg', fit: BoxFit.cover);
  }
}

final Map<String, Widget?> _imageCache = {}; // Stores Widget directly

Widget buildPosterWeb(int index, dynamic movie) {
  final wikipediaUrl = movie['wikipedia'] as String?;
  final movieTitle = movie['title'] as String? ?? 'film';
  final movieOriginalTitle = movie['english_title'] as String? ?? movieTitle;
  final genre = movie['genre'] as String? ?? 'genre';
  var imageName =
      '${movieOriginalTitle.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.jpg';
  imageName = imageName.toLowerCase();
  final imagePath = 'assets/posters/$imageName';
  final posterPrompt = movie['poster_prompt'] as String? ??
      'Locandina dettagliata per il film $movieOriginalTitle';

  // Verifica se l'immagine esiste già negli assets
  return FutureBuilder<bool>(
    future: _checkAssetExists(imagePath),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.done) {
        if (snapshot.data == true) {
          //print('Found in assets : $movieTitle - $imagePath');
          // L'immagine esiste negli assets, usala
          return Image.asset(
            imagePath,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildPosterFallback(index, movie, wikipediaUrl);
            },
          );
        } else {
          // L'immagine non esiste negli assets, procedi con il tentativo di scraping
          return FutureBuilder<Widget>(
            future: _getWikipediaImageUrl(wikipediaUrl).then((imageUrl) {
              if (imageUrl.isNotEmpty) {
                //print('Loading $imageUrl');
                return _CachedImageLoader(
                  imageUrl: imageUrl,
                  placeholderIndex: index,
                );
              } else {
                return generateImage(movieTitle, posterPrompt, genre);
              }
            }),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return snapshot.data!;
              } else if (snapshot.hasError) {
                return _buildPosterFallback(index, movie, wikipediaUrl);
              } else {
                return const Center(child: CircularProgressIndicator());
              }
            },
          );
        }
      } else {
        // Mostra un indicatore di caricamento durante la verifica dell'asset
        return const Center(child: CircularProgressIndicator());
      }
    },
  );
}

Future<bool> _checkAssetExists(String assetPath) async {
  try {
    await rootBundle.load(assetPath);
    return true;
  } catch (e) {
    return false;
  }
}

Widget _buildPosterFallback(int index, dynamic movie, String? wikipediaUrl) {
  return FutureBuilder<Widget>(
    future: generateImage(
        movie['title'] as String? ?? 'film',
        movie['poster_prompt'] as String? ??
            'Generica locandina cinematografica',
        movie['genre'] as String? ?? 'genre'),
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        return snapshot.data!;
      } else if (snapshot.hasError) {
        return placeHolderImage(movie['title']);
      } else {
        return const Center(child: CircularProgressIndicator());
      }
    },
  );
}

// Funzione per ottenere la directory di cache persistente
Future<String> _getCacheDirectory() async {
  final directory = await getApplicationDocumentsDirectory();
  final cacheDir = Directory('${directory.path}/generated_image_cache');
  if (!await cacheDir.exists()) {
    await cacheDir.create(recursive: true);
  }
  return cacheDir.path;
}

Future<bool> saveImageToCache(String movieTitle, Uint8List imageBytes) async {
  try {
    // Save to in-memory cache first
    _inMemoryCache[movieTitle] = imageBytes;

    // Then save to storage
    if (kIsWeb) {
      return await saveImageToCacheWeb(movieTitle, imageBytes);
    } else {
      return await saveImageToCacheMobile(movieTitle, imageBytes);
    }
  } catch (e) {
    print('Errore nel salvataggio in cache: $e');
    return false;
  }
}

// Implementazione mobile
Future<bool> saveImageToCacheMobile(
    String movieTitle, Uint8List imageBytes) async {
  try {
    final cacheDir = await _getCacheDirectory();
    final filename =
        '${movieTitle.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.png';
    final file = File('$cacheDir/$filename');
    await file.writeAsBytes(imageBytes);
    //print('Immagine salvata in cache mobile per: $movieTitle');
    return true;
  } catch (e) {
    print('Errore salvataggio mobile: $e');
    return false;
  }
}

// Funzione per caricare l'immagine generata dal disco (solo per mobile)
Future<File?> _loadGeneratedImageMobile(String movieTitle) async {
  final cacheDir = await _getCacheDirectory();
  try {
    final filename =
        '${movieTitle.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.png';
    final file = File('$cacheDir/$filename');
    if (await file.exists()) {
      return file;
    }
    return null;
  } catch (e) {
    print(
        'Errore durante il caricamento dell\'immagine generata su mobile: $e');
    return null;
  }
}

Future<Widget?> loadFromCache(String movieTitle) async {
  try {
    // Check in-memory cache first
    if (_inMemoryCache.containsKey(movieTitle)) {
      //print('Restituisco immagine dalla cache in memoria per: $movieTitle');
      return Image.memory(_inMemoryCache[movieTitle]!, fit: BoxFit.cover);
    }

    // If not found in memory, check storage
    if (kIsWeb) {
      final bytes = await _loadGeneratedImageWeb(movieTitle);
      return bytes != null ? Image.memory(bytes, fit: BoxFit.cover) : null;
    } else {
      final file = await _loadGeneratedImageMobile(movieTitle);
      return file != null ? Image.file(file, fit: BoxFit.cover) : null;
    }
  } catch (e) {
    print('Errore nel caricamento dalla cache: $e');
    return null;
  }
}

final Map<String, Uint8List> _inMemoryCache = {}; // In-memory cache for images
// Aggiungi queste costanti in cima al file
const int _maxWebCacheItems = 20;
const int _maxWebCacheSizeMB = 50;

Future<bool> saveImageToCacheWeb(
    String movieTitle, Uint8List imageBytes) async {
  try {
    // 1. Compressione dell'immagine
    final compressedBytes = await _compressImage(imageBytes);

    // 2. Controllo dimensione singola immagine
    if (compressedBytes.lengthInBytes > 5 * 1024 * 1024) {
      // 5MB
      //print('Immagine troppo grande, salto il caching');
      return false;
    }

    // 3. Pulizia preventiva della cache
    await _cleanWebCache();

    // 4. Salvataggio con timestamp
    final cacheKey = 'generated_image_$movieTitle';
    final cacheData = {
      'data': base64Encode(compressedBytes),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'size': compressedBytes.lengthInBytes,
    };

    html.window.localStorage[cacheKey] = jsonEncode(cacheData);
    //print('Salvato in cache: $cacheKey');
    return true;
  } catch (e) {
    print('Errore salvataggio web: $e');
    return false;
  }
}

Future<Uint8List> _compressImage(Uint8List bytes) async {
  try {
    final image = img.decodeImage(bytes);
    if (image == null) return bytes;

    // Ridimensiona l'immagine mantenendo le proporzioni
    final resized = img.copyResize(
      image,
      width: 100,
      interpolation: img.Interpolation.average,
    );

    // Converti in JPEG con qualità regolabile
    return Uint8List.fromList(
      img.encodeJpg(resized, quality: 80),
    );
  } catch (e) {
    print('Errore compressione immagine: $e');
    return bytes;
  }
}

Future<void> _cleanWebCache() async {
  try {
    final keys = html.window.localStorage.keys
        .where((k) => k.startsWith('generated_image_'))
        .toList();

    // Calcola dimensione totale e ordina per timestamp
    int totalSize = 0;
    final List<Map<String, dynamic>> items = [];

    for (final key in keys) {
      final data = jsonDecode(html.window.localStorage[key]!);
      items.add(
          {'key': key, 'size': data['size'], 'timestamp': data['timestamp']});
      totalSize += (data['size'] as int).toInt();
    }

    // Ordina dal più vecchio al più recente
    items.sort((a, b) => a['timestamp'].compareTo(b['timestamp']));

    // Elimina elementi eccedenti
    while (items.length > _maxWebCacheItems ||
        totalSize > _maxWebCacheSizeMB * 1024 * 1024) {
      final oldest = items.removeAt(0);
      html.window.localStorage.remove(oldest['key']);
      totalSize += (oldest['size'] as int).toInt();
      //print('Rimosso dalla cache: ${oldest['key']}');
    }
  } catch (e) {
    print('Errore pulizia cache: $e');
  }
}

// Modifica il metodo di caricamento
Future<Uint8List?> _loadGeneratedImageWeb(String movieTitle) async {
  final cacheKey = 'generated_image_$movieTitle';
  final cachedData = html.window.localStorage[cacheKey];

  if (cachedData != null) {
    try {
      final data = jsonDecode(cachedData);
      // Aggiorna timestamp per LRU
      data['timestamp'] = DateTime.now().millisecondsSinceEpoch;
      html.window.localStorage[cacheKey] = jsonEncode(data);
      //print('Letto da  cache: $cacheKey');
      return base64Decode(data['data']);
    } catch (e) {
      html.window.localStorage.remove(cacheKey);
    }
  }
  return null;
}

final Map<String, Map<String, dynamic>> _personaDataCache = {};

Future<Map<String, dynamic>> getPErsonaData(String fileNumber) async {
  // Controlla se i dati sono già in cache
  if (_personaDataCache.containsKey(fileNumber)) {
    return _personaDataCache[fileNumber]!;
  }

  try {
    final personaJson = await _loadPersonaJson(fileNumber);
    final Map<String, dynamic> personaData = jsonDecode(personaJson);

    // Salva nella cache prima di restituire
    _personaDataCache[fileNumber] = personaData;

    return personaData;
  } catch (e) {
    print('Errore nel caricamento del persona $fileNumber: $e');
    return {}; // Restituisce un oggetto vuoto invece di lanciare eccezione
  }
}

Future<String> _loadPersonaJson(String fileNumber) async {
  try {
    return await rootBundle.loadString('assets/personas/$fileNumber.json');
  } catch (e) {
    print('Errore nel caricamento del persona $fileNumber: $e');
    return '{}'; // Restituisce un JSON vuoto come fallback
  }
}
