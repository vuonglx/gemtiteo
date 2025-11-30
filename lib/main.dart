import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:firebase_core/firebase_core.dart'; // Bỏ comment khi đã setup Firebase
// import 'package:cloud_firestore/cloud_firestore.dart'; // Bỏ comment khi đã setup Firebase

// --- CẤU HÌNH ---
// Hãy thay thế bằng API Key thực của bạn
const String GEMINI_API_KEY = 'AIzaSyANy0jqQKx-2YAWCpRsQbDW7Ob2imGEFBc'; 
const String GEMINI_URL = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$GEMINI_API_KEY';

// --- DỮ LIỆU MẪU ---
final List<String> START_WORDS = [
  "Con Mèo", "Cái Ghế", "Bầu Trời", "Mặt Đất", "Dòng Sông",
  "Bánh Mì", "Xe Đạp", "Học Sinh", "Bác Sĩ", "Công Viên",
  "Mùa Hè", "Trái Cây", "Điện Thoại", "Máy Tính", "Cà Phê"
];

final List<String> RANDOM_SUGGESTIONS = [
  "Bánh", "Kẹo", "Mèo", "Chó", "Gà", "Vịt", "Trời", "Đất", "Sông", "Núi", "Xe", "Pháo"
];

// --- MODELS ---
class Message {
  final String sender; // 'user' hoặc 'bot'
  final String text;
  final String? meaning;
  bool showMeaning;

  Message({
    required this.sender, 
    required this.text, 
    this.meaning, 
    this.showMeaning = false,
  });
}

// --- STATE MANAGEMENT (PROVIDER) ---
class GameState extends ChangeNotifier {
  int coins = 120;
  int streak = 3;
  int correctCount = 0;
  int mistakes = 0;
  List<Message> history = [];
  List<String> usedWords = []; 
  bool isLoading = false;

  int get level {
    if (correctCount >= 50) return 3;
    if (correctCount >= 20) return 2;
    if (correctCount >= 10) return 1;
    return 0;
  }

  GameState() {
    _loadLocalState();
  }

  // --- LOGIC GAME CHUNG ---

  void setLoading(bool value) {
    isLoading = value;
    notifyListeners();
  }

  void addCoins(int amount) {
    coins += amount;
    _saveState();
    notifyListeners();
  }

  // --- LOGIC NỐI TỪ ---
  void startNewGameChain([String? customMsg]) {
    final startWord = START_WORDS[Random().nextInt(START_WORDS.length)];
    history = [
      Message(
        sender: 'bot', 
        text: customMsg ?? 'Chào bạn! Nối từ không? Tôi ra trước nhé: "$startWord"',
      )
    ];
    usedWords = [startWord.toLowerCase()];
    mistakes = 0;
    isLoading = false;
    notifyListeners();
  }

  void addMessage(Message msg) {
    history.add(msg);
    notifyListeners();
  }

  void toggleMeaning(int index) {
    if (index >= 0 && index < history.length) {
      history[index].showMeaning = !history[index].showMeaning;
      notifyListeners();
    }
  }

  void handleWinChain() {
    coins += 100;
    correctCount += 3;
    _saveState();
    notifyListeners();
  }

  void handleCorrectMoveChain(String userWord, String botWord) {
    coins += 10;
    correctCount += 1;
    usedWords.add(userWord.toLowerCase());
    usedWords.add(botWord.toLowerCase());
    mistakes = 0; 
    _saveState();
    notifyListeners();
  }

  void incrementMistakeChain() {
    mistakes++;
    notifyListeners();
  }

  // --- PERSISTENCE ---
  Future<void> _loadLocalState() async {
    final prefs = await SharedPreferences.getInstance();
    coins = prefs.getInt('coins') ?? 120;
    streak = prefs.getInt('streak') ?? 3;
    correctCount = prefs.getInt('correctCount') ?? 0;
    
    if (history.isEmpty) startNewGameChain(); 
    notifyListeners();
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('coins', coins);
    prefs.setInt('streak', streak);
    prefs.setInt('correctCount', correctCount);
  }
}

// --- API HELPER (GEMINI) ---
Future<dynamic> callGemini(String prompt) async {
  try {
    final response = await http.post(
      Uri.parse(GEMINI_URL),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "contents": [{"parts": [{"text": prompt}]}]
      }),
    );

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
      final text = jsonResponse['candidates']?[0]['content']?['parts']?[0]?['text'];
      
      if (text != null) {
        final cleanText = text.replaceAll(RegExp(r'```json|```'), '').trim();
        try {
          return jsonDecode(cleanText);
        } catch (e) {
          return text;
        }
      }
    } else {
      debugPrint("API Error: ${response.statusCode}");
    }
  } catch (e) {
    debugPrint("Network Error: $e");
  }
  return null;
}

// --- MAIN APP ---
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // await Firebase.initializeApp(); // Bỏ comment sau khi cài Firebase
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => GameState(),
      child: MaterialApp(
        title: 'Tí Tẹo',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
          fontFamily: 'Roboto',
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 1,
            iconTheme: IconThemeData(color: Colors.black87),
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}

// --- MÀN HÌNH CHÍNH (HOME) ---
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0; // Mặc định vào Ghép Từ

  final List<Widget> _widgetOptions = <Widget>[
    const GamePairingScreen(), 
    const GameChainScreen(),   
    const Center(child: Text("Chế độ Họa Sĩ AI (Sắp ra mắt)", style: TextStyle(color: Colors.grey))),
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Colors.orange, Colors.yellow]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('T', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tí Tẹo', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      const Icon(Icons.person, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('LEVEL ${state.level}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                    ],
                  ),
                )
              ],
            )
          ],
        ),
        actions: [
          _buildStat(Icons.local_fire_department, '${state.streak}', Colors.orange),
          const SizedBox(width: 8),
          _buildStat(Icons.monetization_on, '${state.coins}', Colors.yellow[800]!, bg: Colors.yellow[50]!, border: Colors.yellow[700]!),
          const SizedBox(width: 16),
        ],
      ),
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.bolt), label: 'Ghép Từ'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Nối Từ'),
          BottomNavigationBarItem(icon: Icon(Icons.palette_outlined), label: 'Họa Sĩ'),
        ],
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }

  Widget _buildStat(IconData icon, String label, Color color, {Color? bg, Color? border}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg ?? color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border ?? color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

// --- MÀN HÌNH GHÉP TỪ (GAME PAIRING) ---
class GamePairingScreen extends StatefulWidget {
  const GamePairingScreen({super.key});

  @override
  State<GamePairingScreen> createState() => _GamePairingScreenState();
}

class _GamePairingScreenState extends State<GamePairingScreen> {
  final TextEditingController _word1Controller = TextEditingController();
  final TextEditingController _word2Controller = TextEditingController();
  bool _isProcessing = false;

  Future<void> _handleCombine() async {
    final w1 = _word1Controller.text.trim();
    final w2 = _word2Controller.text.trim();
    if (w1.isEmpty || w2.isEmpty || _isProcessing) return;

    setState(() => _isProcessing = true);
    
    final prompt = '''
      Act as a witty Vietnamese word alchemy game.
      User combines: "$w1" + "$w2".
      TASK: Create a result that is a cleverly associated "Compound Word" or "Concept Name".
      CONSTRAINT: The result word MUST NOT contain the original words "$w1" or "$w2".
      
      Logic Examples:
      - "Bạc" + "Nước" -> "Thủy Ngân" (Mercury).
      - "Lửa" + "Nước" -> "Hơi Nước".
      
      IMPORTANT: All text in JSON must be Vietnamese.
      Return ONLY JSON:
      {
        "result": "Kết quả từ ghép",
        "desc": "Mô tả ngắn gọn hài hước",
        "icon": "Emoji biểu tượng",
        "reason": "Lý do/Châm biếm hài hước tại sao $w1 + $w2 = kết quả này"
      }
    ''';

    final result = await callGemini(prompt);

    // FIX: Ép kiểu an toàn từ dynamic (Map<dynamic, dynamic>) sang Map<String, dynamic>
    if (result != null && result is Map) {
      final Map<String, dynamic> data = Map<String, dynamic>.from(result);
      if (mounted) {
        _showResultDialog(context, data);
        context.read<GameState>().addCoins(15);
      }
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lỗi kết nối AI hoặc kết quả không hợp lệ!")));
    }

    setState(() => _isProcessing = false);
    _word1Controller.clear();
    _word2Controller.clear();
  }
  
  void _fillSuggestion(String word) {
    if (_word1Controller.text.isEmpty) {
      _word1Controller.text = word;
    } else if (_word2Controller.text.isEmpty) {
      _word2Controller.text = word;
    }
  }

  void _showResultDialog(BuildContext context, Map<String, dynamic> data) {
      showDialog(
          context: context,
          builder: (ctx) => Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header Image Area
                      Container(
                        height: 250,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Colors.orange, Colors.deepOrange]),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10)]
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(data['icon'] ?? '✨', style: const TextStyle(fontSize: 80)),
                              const SizedBox(height: 10),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  (data['result'] ?? '???').toUpperCase(),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, shadows: [Shadow(color: Colors.black26, blurRadius: 10)]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Body
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Text(data['desc'] ?? '', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black87)),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.withOpacity(0.3))),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.lightbulb, color: Colors.amber, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(data['reason'] ?? '', style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.black87))),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => Navigator.pop(ctx),
                                    icon: const Icon(Icons.share, color: Colors.white),
                                    label: const Text("Khoe", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, padding: const EdgeInsets.symmetric(vertical: 12)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                                    child: const Text("Chơi tiếp", style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),
          ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("Phòng Thí Nghiệm 🧪", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
          const Text("Ghép 2 từ thành 1 khái niệm bá đạo!", style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
          const SizedBox(height: 30),
          
          // Inputs
          Row(
            children: [
              Expanded(child: _buildInput(_word1Controller, "Từ 1")),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.add, size: 30, color: Colors.black54)),
              Expanded(child: _buildInput(_word2Controller, "Từ 2")),
            ],
          ),
          const SizedBox(height: 30),

          // Button
          ElevatedButton.icon(
            onPressed: _isProcessing ? null : _handleCombine,
            icon: _isProcessing 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.flash_on, color: Colors.white),
            label: Text(_isProcessing ? "ĐANG CHẾ TẠO..." : "HỢP THỂ! ⚡", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[700],
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              elevation: 5,
            ),
          ),
          
          const SizedBox(height: 40),
          const Text("NGUYÊN LIỆU GỢI Ý:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey), textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: RANDOM_SUGGESTIONS.map((w) => ActionChip(
              label: Text(w, style: const TextStyle(fontWeight: FontWeight.w600)),
              onPressed: () => _fillSuggestion(w),
              backgroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade300)),
            )).toList(),
          )
        ],
      ),
    );
  }

  Widget _buildInput(TextEditingController controller, String hint) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Center(
        child: TextField(
          controller: controller,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 18, fontWeight: FontWeight.normal),
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          textCapitalization: TextCapitalization.words,
        ),
      ),
    );
  }
}

// --- MÀN HÌNH GAME NỐI TỪ ---
class GameChainScreen extends StatefulWidget {
  const GameChainScreen({super.key});

  @override
  State<GameChainScreen> createState() => _GameChainScreenState();
}

class _GameChainScreenState extends State<GameChainScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isHintLoading = false;

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _handleHint() async {
    if (_isHintLoading) return;
    setState(() => _isHintLoading = true);

    final state = context.read<GameState>();
    String lastBotMsg = state.history.isNotEmpty ? state.history.last.text : "";
    String lastBotWord = "";
    final RegExp quoteRegex = RegExp(r'"([^"]+)"');
    final match = quoteRegex.firstMatch(lastBotMsg);
    if (match != null) {
      lastBotWord = match.group(1)!;
    } else {
      lastBotWord = lastBotMsg.split(RegExp(r'[ .?!,]+')).last;
    }
    final realLastSyllable = lastBotWord.trim().split(RegExp(r'\s+')).last;

    final prompt = '''
      Context: Vietnamese Word Chain game.
      Target syllable: "$realLastSyllable".
      Used Words List: ${jsonEncode(state.usedWords)}.
      Task: Suggest ONE valid compound word that starts with EXACTLY "$realLastSyllable" (must match accents).
      Constraint 1: The word must have EXACTLY 2 syllables.
      Constraint 2: Must be a common dictionary word.
      Constraint 3: The word must NOT be in the "Used Words List".
      If no valid word exists or you cannot find one, return exactly "NOT_FOUND".
      Return ONLY the word text or "NOT_FOUND".
    ''';

    final result = await callGemini(prompt);
    if (result != null) {
      String hintWord = "";
      if (result is String) {
        hintWord = result.trim();
      } else if (result is Map && result.containsKey('word')) hintWord = result['word'];

      if (hintWord == "NOT_FOUND" || hintWord.isEmpty) {
        state.addMessage(Message(sender: 'bot', text: 'Tôi cũng không nghĩ ra, bạn cố gắng đi nhé!'));
      } else {
        _controller.text = hintWord;
      }
    }
    setState(() => _isHintLoading = false);
  }

  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    final state = context.read<GameState>();
    if (text.isEmpty || state.isLoading || state.mistakes >= 2) return;

    state.setLoading(true);
    _controller.clear();
    state.addMessage(Message(sender: 'user', text: text));
    _scrollToBottom();

    if (state.usedWords.contains(text.toLowerCase())) {
      await Future.delayed(const Duration(milliseconds: 500));
      _handleMistake("Từ này đã dùng rồi nha!", state);
      state.setLoading(false);
      _scrollToBottom();
      return;
    }

    String lastBotWord = "";
    if (state.history.length >= 2) {
      final prevBotMsg = state.history[state.history.length - 2].text;
      final RegExp quoteRegex = RegExp(r'"([^"]+)"');
      final match = quoteRegex.firstMatch(prevBotMsg);
      if (match != null) {
        lastBotWord = match.group(1)!;
      } else {
        lastBotWord = prevBotMsg.split(RegExp(r'[ .?!,]+')).last;
      }
    }

    final prompt = '''
      Game: Vietnamese Word Chain (Nối từ).
      Persona: Strict Vietnamese Linguist & Friendly Player.
      Current State:
      - Previous Word: "$lastBotWord"
      - User Input: "$text"
      - Used Words List: ${jsonEncode(state.usedWords)}

      TASK:
      SCENARIO A: User asks for meaning (e.g., "nghĩa là gì").
      - Return JSON: {"type": "explain", "message": "Giải thích ngắn gọn tiếng Việt. Vẫn là từ '$lastBotWord' nha!"}

      SCENARIO B: User plays a move.
      1. CHECK VALIDITY: 
         - User's word MUST start with the EXACT last word of "$lastBotWord" (matching accents).
         - User's word MUST have EXACTLY 2 syllables.
         - User's word MUST be a VALID, MEANINGFUL Vietnamese word found in a standard dictionary.
         - User's word must NOT be in the Used Words List.
      2. IF INVALID: Return JSON: {"type": "invalid", "message": "Sai rồi! [Giải thích ngắn gọn]"}
      3. IF VALID:
         - Find a response word starting with the last word of "$text".
         - MUST be a valid dictionary word.
         - MUST have EXACTLY 2 syllables.
         - MUST NOT be in the Used Words List.
         - CRITICAL: Do NOT invent words or definitions (e.g., "mun sữa" is FALSE).
         - IF YOU CANNOT FIND A WORD: Return JSON: {"type": "surrender"}
         - IF FOUND: Return JSON: {"type": "valid", "word": "YOUR_WORD", "meaning": "Short definition"}
      
      Return ONLY JSON object.
    ''';

    final result = await callGemini(prompt);

    // FIX: Ép kiểu an toàn từ dynamic (Map<dynamic, dynamic>) sang Map<String, dynamic>
    if (result != null && result is Map) {
      final Map<String, dynamic> data = Map<String, dynamic>.from(result);
      final type = data['type'];
      
      if (type == 'valid') {
        final botWord = data['word'];
        final meaning = data['meaning'];
        
        final userLastSyl = text.trim().split(' ').last.toLowerCase().replaceAll(RegExp(r'[.,!?;:]'), '');
        final botFirstSyl = botWord.toString().trim().split(' ').first.toLowerCase().replaceAll(RegExp(r'[.,!?;:]'), '');

        if (userLastSyl != botFirstSyl) {
           state.addMessage(Message(sender: 'bot', text: 'Ái chà, tôi nhầm rồi! Từ "$botWord" không nối được với "$text". Bạn thắng! 🏆'));
           state.handleWinChain();
           _triggerResetDelay(state);
        } else {
           state.addMessage(Message(sender: 'bot', text: 'OK! "$botWord"', meaning: meaning));
           state.handleCorrectMoveChain(text, botWord);
        }
      } else if (type == 'invalid') {
        _handleMistake(data['message'], state);
      } else if (type == 'surrender') {
        state.addMessage(Message(sender: 'bot', text: 'Chà, từ này khó quá! Tôi đầu hàng. Bạn thắng rồi! 🏆'));
        state.handleWinChain();
        _triggerResetDelay(state);
      } else if (type == 'explain') {
        state.addMessage(Message(sender: 'bot', text: data['message']));
      }
    } else {
      state.addMessage(Message(sender: 'bot', text: 'Mạng lag quá, thử lại nhé!'));
    }
    state.setLoading(false);
    _scrollToBottom();
  }

  void _handleMistake(String msg, GameState state) {
    state.incrementMistakeChain();
    if (state.mistakes >= 2) {
      state.addMessage(Message(sender: 'bot', text: '$msg\nSai lần 2 rồi! Game này mình thắng 😜'));
      _triggerResetDelay(state);
    } else {
      state.addMessage(Message(sender: 'bot', text: '$msg\nBạn chọn từ khác đi.'));
    }
  }

  void _triggerResetDelay(GameState state) {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) state.startNewGameChain("Ván mới nào! Tôi ra trước nhé (từ bất kỳ).");
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    return Column(
      children: [
        // AI Status Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.white,
          child: Row(
            children: [
              const CircleAvatar(backgroundColor: Colors.blue, radius: 16, child: Text("AI", style: TextStyle(color: Colors.white, fontSize: 12))),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("AI Siêu Cấp", style: TextStyle(fontWeight: FontWeight.bold)),
                  Text("Online", style: TextStyle(color: Colors.green[600], fontSize: 10)),
                ],
              ),
              const Spacer(),
              Row(children: List.generate(2, (index) => Icon(Icons.favorite, size: 20, color: index < (2 - state.mistakes) ? Colors.red : Colors.grey[300]))),
              const SizedBox(width: 12),
              IconButton(icon: _isHintLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.lightbulb, color: Colors.amber), onPressed: _handleHint),
              IconButton(icon: const Icon(Icons.refresh, color: Colors.grey), onPressed: () => state.startNewGameChain()),
            ],
          ),
        ),
        const Divider(height: 1),
        // Chat Area
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: state.history.length,
            itemBuilder: (context, index) {
              final msg = state.history[index];
              final isUser = msg.sender == 'user';
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                      children: [
                        Container(
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isUser ? Colors.blue : Colors.white,
                            borderRadius: BorderRadius.circular(20).copyWith(
                              bottomRight: isUser ? Radius.zero : const Radius.circular(20),
                              topLeft: isUser ? const Radius.circular(20) : Radius.zero,
                            ),
                            border: isUser ? null : Border.all(color: Colors.grey.shade200),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))],
                          ),
                          child: Text(msg.text, style: TextStyle(color: isUser ? Colors.white : Colors.black87, fontSize: 15)),
                        ),
                        if (!isUser && msg.meaning != null)
                          Padding(padding: const EdgeInsets.only(left: 8), child: InkWell(onTap: () => state.toggleMeaning(index), child: const Icon(Icons.info_outline, size: 20, color: Colors.blue))),
                      ],
                    ),
                    if (msg.showMeaning && msg.meaning != null)
                      Container(
                        margin: const EdgeInsets.only(top: 6, left: 4),
                        padding: const EdgeInsets.all(8),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                        decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.withOpacity(0.2))),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.lightbulb, size: 14, color: Colors.amber),
                            const SizedBox(width: 6),
                            Flexible(child: Text(msg.meaning!, style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.black87))),
                          ],
                        ),
                      )
                  ],
                ),
              );
            },
          ),
        ),
        // Input Area
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade200))),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: state.mistakes < 2 && !state.isLoading,
                    decoration: InputDecoration(
                      hintText: "Nhập từ nối tiếp...",
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                    onSubmitted: (_) => _handleSend(),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: (state.mistakes < 2 && !state.isLoading) ? _handleSend : null,
                  backgroundColor: state.isLoading ? Colors.grey : Colors.blue,
                  elevation: 0,
                  child: state.isLoading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
