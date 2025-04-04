import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'generated/l10n.dart';

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
import 'package:intl/intl.dart';
import 'package:cine_match/generated/l10n.dart';
var selectedCritic = '01';
var model;
const criticsNumber = 4;
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initFirebase();
  await _QuizPageState.loadReceivedTitles(); // Carica i titoli salvati

  runApp(const MyApp());
}

/*
String get appName {
  return Intl.message(
    'Cine Match',
    name: 'appName',
    desc: 'The title of the application',
  );
}

*/


Future<void> initFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print('Error  $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "CineMatch",
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.delegate.supportedLocales,
      theme: _buildAppTheme(),
      home: const ImageSelectionScreen(),
    );
  }

  ThemeData _buildAppTheme() {
    const surfaceColor = Color(0xFF2A2A2A);
    final amberShade600 = Colors.amber.shade600;
    final redShade900 = Colors.red.shade900;

    return ThemeData(
      appBarTheme: _buildAppBarTheme(),
      iconTheme: _buildIconTheme(amberShade600),
      colorScheme: _buildColorScheme(redShade900, amberShade600, surfaceColor),
      useMaterial3: true,
      textTheme: _buildTextTheme(amberShade600),
      cardTheme: _buildCardTheme(redShade900),
    );
  }

  AppBarTheme _buildAppBarTheme() {
    return const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 4,
    );
  }

  IconThemeData _buildIconTheme(Color iconColor) {
    return IconThemeData(
      color: iconColor,
      size: 40,
    );
  }

  ColorScheme _buildColorScheme(Color primaryColor, Color secondaryColor, Color surfaceColor) {
    return ColorScheme.dark(
      primary: primaryColor,
      secondary: secondaryColor,
      surface: surfaceColor,
      onPrimary: Colors.white,
    );
  }

  TextTheme _buildTextTheme(Color amberShade600) {
    return TextTheme(
      displayLarge: TextStyle(
        fontFamily: 'Vintage',
        fontSize: 32,
        color: amberShade600,
      ),
      bodyLarge: const TextStyle(color: Colors.white70),
      bodyMedium: TextStyle(
        color: Colors.grey.shade400,
        height: 1.4,
      ),
    );
  }

  CardTheme _buildCardTheme(Color borderColor) {
    return CardTheme(
      color: const Color(0xFF1E1E1E),
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: borderColor, width: 1),
      ),
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


  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: BackgroundWidget(
        child: FutureBuilder<List<String>>(
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
      ),),
    );
  }

  Widget _buildMainContent(List<String> descriptions) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.7, // Modificato per meglio adattarsi ai ritratti
                  ),
                  itemCount: criticsNumber,
                  itemBuilder: (context, index) {
                    final imageNumber = (index + 1).toString().padLeft(2, '0');
                    final imagePath = 'assets/images/$imageNumber.png';
                    return _buildCriticoCard(imagePath, index, descriptions);
                  },
                )
              ),
              // Pulsante per il critico personalizzato
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      selectedCritic = '05'; // Assume che il 5° critico sia il personalizzato
                      setState(() => _selectedImageNumber = selectedCritic);
                      _navigateToQuiz();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black.withOpacity(0.7),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                        side: BorderSide(
                          color: Colors.amber.shade600,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_search_rounded,
                          color: Colors.amber.shade600,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Critico personalizzato',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCriticoCard(String imagePath, int index, List<String> descriptions) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: _selectedImageNumber == imagePath.split('/').last.split('.').first
              ? Colors.amber.shade600
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () {
          selectedCritic = imagePath.split('/').last.split('.').first;
          setState(() => _selectedImageNumber = selectedCritic);
          _navigateToQuiz();
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Nome del critico
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                descriptions[index],
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 4),
            // Immagine con crop centrato
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 6,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: AspectRatio(
                      aspectRatio: 0.75, // Proporzioni tipiche di un ritratto
                      child: Image.asset(
                        imagePath,
                        fit: BoxFit.cover, // Crop centrato che riempie lo spazio
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
    for (int i = 1; i <= criticsNumber; i++) {
      final fileNumber = i.toString().padLeft(2, '0');
      try {
        final jsonData = await getPersonaData(fileNumber);
        descriptions
            .add(jsonData['name'] ?? '?');
      } catch (e) {
        print('Error loading del persona $fileNumber: $e');
        descriptions.add('?');
      }
    }
    return descriptions;
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
      print('Error CRITICO: $error');
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
        print('Asking gemini:...');
        List<dynamic> movieList2 = await askGemini(role + prompt);
        movieList.addAll(movieList2);
      }

      if (movieList.isEmpty || movieList.length < 4) {
        print('Asking pollination:...');
        List<dynamic> movieList2 = await askPollination(role, prompt);
        movieList.addAll(movieList2);
      }

      if (movieList.isEmpty || movieList.length < 4) {
        print('Asking mistral:...');
        List<dynamic> movieList2 =await askMistral(role, answers);
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
        print('Error nella risposta: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error durante la richiesta a Pollinations: $e');
      return [];
    }
  }

  Future<List<dynamic>> askMistral(String role, List<Map<String, String>> answers) async {
    try {
      const keyMistral = String.fromEnvironment('KEY_MISTRAL');
      if (keyMistral.isEmpty) {
        throw AssertionError('KEY_MISTRAL is not set');
      }

      // Costruisci la conversazione
      final List<Map<String, String>> messages = [
        {"role": "system", "content": role},
      ];

      // Aggiungi ogni domanda e risposta come turni di conversazione
      for (final answer in answers) {
        messages.add({
          "role": "assistant",
          "content": answer['question'] ?? 'Domanda non disponibile'
        });
        messages.add({
          "role": "user",
          "content": answer['answer'] ?? 'Risposta non disponibile'
        });
      }

      // Aggiungi l'ultimo prompt con le istruzioni specifiche
      messages.add({
        "role": "user",
        "content": """
      Ora genera  una lista di film raccomandati in base alle tue risposte. 
      Il formato di ritorno sarà un array JSON con i seguenti campi per ogni film:
      - title: Titolo del film (edizione italiana)
      - english_title: Titolo originale
      - wikipedia: Link Wikipedia
      - description: Breve sinossi
      - score: Punteggio 1-10
      - genre: Genere principale scelto tra [action, horror, adventure,musical, comedy ,science-fiction ,crime ,war ,drama ,western, historical]
      - why_recommended: Lunga e argomentata motivazione della raccomandazione e dei legami con le risposte dell'utente. in questo attributo il critico riversa la sua personalita
      - poster_prompt: Descrizione per generare la locandina

      ***IMPORTANTE***:
      - Produci almeno 4 risultati
      - Ordina per score decrescente
      - Includi solo film realmente esistenti
      - Usa encoding corretto per caratteri italiani
      - Ritorna SOLO il JSON valido, senza commenti o markdown
      """
      });

      final url = Uri.parse('https://api.mistral.ai/v1/chat/completions');
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $keyMistral',
      };

      final body = jsonEncode({
        "model": "mistral-small-latest",
        "messages": messages,
        "temperature": 0.7,
        "response_format": {"type": "json_object"}, // Specifica il return type
        "max_tokens": 8000
      });

      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final responseJson = jsonDecode(response.body);
        final content = responseJson['choices'][0]['message']['content'] as String;

        // Pulizia e parsing del JSON
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
        print('Error nella risposta: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('Error durante la richiesta a Mistral: $e');
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
      print('Error durante la richiesta a Gemini: $e');
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


    String exampleContent = _defaultExampleContent();
    String  postContent = _defaultPostContent();
    if (_receivedTitles.length > 100) _receivedTitles.removeRange(0, 5);
    String exclusionInstruction = _receivedTitles.isNotEmpty
        ? "\nEscludi ASSOLUTAMENTE questi film: ${_receivedTitles.join(', ')}.\n"
        : "";
    final special = "\n.Produci in ogni caso almeno 4 risultati.\n"
        "$exclusionInstruction"
    "Nel campo \"why_reccomended\" scrivi testi lungghi e articolato\n."
        "Aggiungi anche un film che non c'entra e giustificane in modo arzigogolato la scelta nel campo \"why_recomended\".\n"
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
        "'genre': un solo genere  a cui appartiene il film scelto tra [action, horror, adventure,musical, comedy ,science-fiction ,crime ,war ,drama ,western, historical]\n"
        "‘why_recommended’: spiegazione argomentata dei pregi del film e della sua attinenza con le riposte dell'utente‘";

    final res =
        "\n$summary\n$jsonDesc\n$postContent$exampleContent\n\n$special";
    //print('Prompt:\n $res');
    return res;
  }

  Future<String> _buildRecommendationRole() async {
    final String fileNumber = widget.selectedImage;
    Map<String, dynamic> personaData = await getPersonaData(fileNumber);

    // Estrazione dei contenuti dal JSON
    String preContent = personaData['role'] ?? '';

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
      "***ISTRUZIONI SPECIALI:  deve essere prodotto solo il json finale, senza altri comment senza caraterai speciali e apici o doppi apici";

  Future<String> _loadAssetFile(String path) async {
    try {
      return await rootBundle.loadString(path);
    } catch (e) {
      print('Error loading del file $path: $e');
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
    print('Error durante la generazione delle raccomandazioni: $error');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Error nel generare raccomandazioni.')),
    );

    Navigator.pop(context); // Torna alla schermata precedente
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
    body: BackgroundWidget(
    child:Stack(
        children: [
          _buildBackground(),
          _buildMainContent(),
        ],
      ),),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_rounded,
          color: Colors.amber.shade600,
          size: 28,
        ),
        onPressed: () => _handleBackAction(),
        tooltip: 'Indietro',
      ),
      title: FutureBuilder<Map<String, dynamic>>(
        future: getPersonaData(widget.selectedImage),
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
              InkWell(
                onTap: () => _showCriticDescription(context),
                child: Row(
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
              ),
            ],
          );
        },
      ),
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
  void _handleBackAction() {
    if (_currentQuestionIndex > 0) {
      // Torna alla domanda precedente
      setState(() {
        _currentQuestionIndex--;
        _selectedAnswer = null;
        // Rimuovi l'ultima risposta se esiste
        if (_answers.length > _currentQuestionIndex) {
          _answers.removeLast();
        }
      });
    } else {
      // Torna alla schermata di selezione dei critici
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const ImageSelectionScreen()),
            (route) => false,
      );
    }
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
                    'assets/images/$selectedCritic.png',
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
        body: BackgroundWidget(
          child: ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: movies.length,
          itemBuilder: (context, index) => _buildMovieItem(context, index),
        ),),
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



Image placeHolderImage(String movieTitle, [String? genre]) {
  // Se non c'è un genere specificato o il file non esiste, usa l'immagine generica
  final String assetPath;

  if (genre != null && genre.isNotEmpty) {
    assetPath = 'assets/genres/${genre.toLowerCase()}.jpg';
  } else {
    assetPath = 'assets/genres/genre.jpg';
  }

  return Image.asset(
    assetPath,
    fit: BoxFit.cover,
    errorBuilder: (context, error, stackTrace) {
      // Se l'immagine specifica non esiste, usa quella generica
      return Image.asset(
        'assets/genres/genre.jpg',
        fit: BoxFit.cover,
      );
    },
  );
}




Future<bool> _checkAssetExists(String assetPath) async {
  try {
    await rootBundle.load(assetPath);
    print('found in path $assetPath');
    return true;
  } catch (e) {
    return false;
  }
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
    print('Error nel salvataggio in cache: $e');
    return false;
  }
}

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
    print('Error salvataggio mobile: $e');
    return false;
  }
}




final Map<String, Uint8List> _inMemoryCache = {}; // In-memory cache for images

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
    print('Error salvataggio web: $e');
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
    print('Error compressione immagine: $e');
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
    print('Error pulizia cache: $e');
  }
}


final Map<String, Map<String, dynamic>> _personaDataCache = {};

Future<Map<String, dynamic>> getPersonaData(String fileNumber) async {
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
    print('Error loading del persona $fileNumber: $e');
    return {}; // Restituisce un oggetto vuoto invece di lanciare eccezione
  }
}

Future<String> _loadPersonaJson(String fileNumber) async {
  try {
    return await rootBundle.loadString('assets/personas/$fileNumber.json');
  } catch (e) {
    print('Error loading del persona $fileNumber: $e');
    return '{}'; // Restituisce un JSON vuoto come fallback
  }
}


Future<String> getWikipediaThumbnailUrl(String movieTitle) async {
  try {
    // Step 1: Search for the Wikipedia page ID or title
    final searchApiUrl = Uri.parse(
        'https://it.wikipedia.org/w/api.php?action=query&list=search&srsearch=${Uri.encodeComponent(movieTitle)}&format=json&srlimit=1');
    final searchResponse = await http.get(searchApiUrl);

    if (searchResponse.statusCode == 200) {
      final searchData = jsonDecode(searchResponse.body);

      if (searchData['query'] != null &&
          searchData['query']['search'] != null &&
          searchData['query']['search'].isNotEmpty) {
        final pageTitle = searchData['query']['search'][0]['title'];

        // Step 2: Get the thumbnail URL using the page title
        final queryApiUrl = Uri.parse(
            'https://it.wikipedia.org/w/api.php?action=query&prop=pageimages&pithumbsize=200&titles=${Uri.encodeComponent(pageTitle)}&format=json');
        print('provo $queryApiUrl');
        final queryResponse = await http.get(queryApiUrl);

        if (queryResponse.statusCode == 200) {

          final queryData = jsonDecode(queryResponse.body);

          if (queryData['query'] != null && queryData['query']['pages'] != null) {
            final pages = queryData['query']['pages'];
            if (pages.isNotEmpty) {
              final pageInfo = pages.values.first;
              if (pageInfo['thumbnail'] != null &&
                  pageInfo['thumbnail']['source'] != null) {

                var res = pageInfo['thumbnail']['source'];
                print('Found  $res');
                return res;
              } else {
                print(
                    'Nessuna miniatura trovata per la pagina di "$movieTitle" su Wikipedia.');
                return '';
              }
            } else {
              print(
                  'Impossibile trovare le informazioni sulla pagina per "$movieTitle" su Wikipedia.');
              return '';
            }
          } else {
            print(
                'Risposta API di query non valida per "$movieTitle" su Wikipedia.');
            return '';
          }
        } else {
          print(
              'Error nella chiamata API di query per "$movieTitle": ${queryResponse.statusCode}');
          return '';
        }
      } else {
        print('Nessun risultato di ricerca trovato per "$movieTitle" su Wikipedia.');
        return '';
      }
    } else {
      print(
          'Error nella chiamata API di ricerca per "$movieTitle": ${searchResponse.statusCode}');
      return '';
    }
  } catch (error) {
    print('Error durante l\'ottenimento della miniatura per "$movieTitle": $error');
    return '';
  }
}


class loadPosterCached {
  static Widget getPoster(String movieTitle, String genre, String desc) {
    return _buildPosterWithFallback(movieTitle, genre, desc);
  }

  static Widget _buildPosterWithFallback(String movieTitle, String genre, String desc) {
    // 1. Cerca prima negli asset locali
    final imageName = _generateImageName(movieTitle);
    final imagePath = 'assets/posters/$imageName';

    return FutureBuilder<bool>(
      future: _checkAssetExists(imagePath),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.data == true) {
            return Image.asset(
              imagePath,
              fit: BoxFit.cover,
            );
          } else {
            // 2. Se non trovato negli asset, cerca su Wikipedia (solo per app mobile)
            if (!kIsWeb) {
              return _buildWikipediaPoster(movieTitle, genre, desc);
            }
            // 3. Per web o se Wikipedia fallisce, genera l'immagine
            return _buildGeneratedPoster(movieTitle, genre, desc);
          }
        }
        // Mostra placeholder durante il caricamento
        return placeHolderImage(movieTitle, genre);
      },
    );
  }

  static Widget _buildWikipediaPoster(String movieTitle, String genre, String desc) {
    return FutureBuilder<String>(
      future: getWikipediaThumbnailUrl(movieTitle),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          return CachedNetworkImage(
            imageUrl: snapshot.data!,
            fit: BoxFit.cover,
            placeholder: (context, url) => placeHolderImage(movieTitle, genre),
            errorWidget: (context, url, error) =>
           _buildGeneratedPoster(movieTitle, genre, desc)
          );
        } else if (snapshot.hasError) {
          return _buildGeneratedPoster(movieTitle, genre, desc);
        }
        return placeHolderImage(movieTitle, genre);
      },
    );
  }

  static Widget _buildGeneratedPoster(String movieTitle, String genre, String? desc) {
    var prompt = 'Poster for the movie: $movieTitle of genre $genre:  $desc. No text';

    final encodedPrompt = Uri.encodeComponent(prompt);
    final imageUrl = 'https://image.pollinations.ai/prompt/$encodedPrompt'
        '?width=240&height=400&seed=${movieTitle.hashCode}'
        '&model=flux&negative_prompt=worst%20quality,%20blurry';

    return FutureBuilder<Uint8List>(
      future: _downloadImage(imageUrl),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Image.memory(
            snapshot.data!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                placeHolderImage(movieTitle, genre),
          );
        } else if (snapshot.hasError) {
          return placeHolderImage(movieTitle, genre);
        }
        return Center(
          child: CircularProgressIndicator(
            color: Colors.amber.shade600,
          ),
        );
      },
    );
  }

  static String _generateImageName(String movieTitle) {
    return movieTitle
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll('.', '_')
        .replaceAll(RegExp(r'^_|_$'), '')
        .trim() + '.jpg';
  }

  static Future<Uint8List> _downloadImage(String url) async {
    try {
      final response = await http.get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        return response.bodyBytes;
      }
      throw Exception('Failed to load image');
    } catch (e) {
      throw Exception('Download error: $e');
    }
  }
}

// Cache in memoria per i poster
final Map<String, Widget> _posterCache = {};
const int _maxCacheSize = 50;

Widget buildPosterWeb(int index, dynamic movie) {
  final movieTitle = movie['title'] as String? ?? 'film';
  final genre = movie['genre'] as String? ?? 'genre';
  final desc  = movie['poster_prompt'] as String? ?? '';

  // Creiamo una chiave unica combinando titolo e genere
  final cacheKey = '${movieTitle}_$genre';

  // Se presente in cache, restituiamo il widget memorizzato
  if (_posterCache.containsKey(cacheKey)) {
    return _posterCache[cacheKey]!;
  }

  // Se la cache è piena, rimuoviamo l'elemento più vecchio
  if (_posterCache.length >= _maxCacheSize) {
    _posterCache.remove(_posterCache.keys.first);
  }

  // Generiamo il nuovo poster e lo memorizziamo in cache
  final poster = loadPosterCached.getPoster(movieTitle, genre,desc);
  _posterCache[cacheKey] = poster;

  return poster;
}

void _showCriticDescription(BuildContext context) async {
  try {
    final personaData = await getPersonaData(selectedCritic);
    final description = personaData['description'] ?? 'Nessuna descrizione disponibile';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black.withOpacity(0.9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(color: Colors.amber.shade600, width: 1.5),
        ),
        title: Text(
          personaData['name'] ?? 'Critico',
          style: TextStyle(
            color: Colors.amber.shade600,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        content: SingleChildScrollView(
          child: Text(
            description,
            style: TextStyle(
              color: Colors.amber.shade100,
              fontSize: 16,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'CHIUDI',
              style: TextStyle(
                color: Colors.amber.shade600,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  } catch (e) {
    print('Error nel mostrare la descrizione: $e');
  }
}

class BackgroundWidget extends StatelessWidget {
  final Widget child;

  const BackgroundWidget({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
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
      child: child,
    );
  }
}