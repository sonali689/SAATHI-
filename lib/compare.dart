import 'dart:ui'; // for ImageFilter
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'result.dart'; // Import your ResultPage

class ComparePage extends StatefulWidget {
  final String gameTitle;
  final bool isHindi;

  const ComparePage({
    Key? key,
    required this.gameTitle,
    required this.isHindi,
  }) : super(key: key);

  @override
  _ComparePageState createState() => _ComparePageState();
}

class _ComparePageState extends State<ComparePage> {
  List<CompareQuestion> questions = [];
  int currentIndex = 0;
  int score = 0;
  int correctCount = 0;
  int incorrectCount = 0;

  /// Map storing the submitted answer index for each question.
  Map<int, int> selectedOptionIndices = {};

  /// Pending selection before submit.
  int? _pendingSelectedIndex;
  bool _hasSubmittedCurrent = false;
  bool _currentIsCorrect = false;

  bool isLoading = true;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  final List<String> shapeAssets = [
    'assets/triangle.png',
    'assets/circle.png',
    'assets/book.png',
    'assets/pencil.png',
  ];
  final Random _random = Random();

  final Map<int, List<String>> _leftAssetsByQuestion = {};
  final Map<int, List<String>> _rightAssetsByQuestion = {};

  @override
  void initState() {
    super.initState();
    _loadGameState().then((_) => _fetchQuestions());
  }

  Future<void> _loadGameState() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final snapshot = await _dbRef
          .child("users/${user.uid}/games/${widget.gameTitle}")
          .get();
      if (!snapshot.exists) return;

      final data = snapshot.value;
      if (data is Map) {
        setState(() {
          score = data['score'] ?? 0;
          correctCount = data['correctCount'] ?? 0;
          incorrectCount = data['incorrectCount'] ?? 0;
          currentIndex = data['currentIndex'] ?? 0;

          // Load saved answers: handle both List and Map
          final raw = data['selectedOptionIndices'];
          if (raw is List) {
            for (int i = 0; i < raw.length; i++) {
              final val = raw[i];
              if (val is int) selectedOptionIndices[i] = val;
            }
          } else if (raw is Map) {
            raw.forEach((key, value) {
              final idx = int.tryParse(key.toString());
              if (idx != null && value is int) {
                selectedOptionIndices[idx] = value;
              }
            });
          }
        });
      }
    } catch (e) {
      print("Error loading game state: $e");
    }
  }

  Future<void> _saveGameState() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final formattedAnswers = selectedOptionIndices
          .map((key, value) => MapEntry(key.toString(), value));

      await _dbRef.child("users/${user.uid}/games/${widget.gameTitle}").update({
        "score": score,
        "correctCount": correctCount,
        "incorrectCount": incorrectCount,
        "currentIndex": currentIndex,
        "selectedOptionIndices": formattedAnswers,
      });
    } catch (e) {
      print("Error saving game state: $e");
    }
  }

  Future<void> _fetchQuestions() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection(widget.gameTitle)
          .orderBy("timestamp")
          .get();

      questions = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return CompareQuestion(
          compareNumber1:
              int.tryParse(data['compareNumber1']?.toString() ?? '') ?? 0,
          compareNumber2:
              int.tryParse(data['compareNumber2']?.toString() ?? '') ?? 0,
          options: (data['options'] as List<dynamic>?)
                  ?.map((option) => CompareOption.fromMap(option))
                  .toList() ??
              [],
          text: data['text'] ?? "",
        );
      }).toList();

      // Prepare random assets
      for (int i = 0; i < questions.length; i++) {
        _leftAssetsByQuestion.putIfAbsent(
            i,
            () => List.generate(questions[i].compareNumber1,
                (_) => shapeAssets[_random.nextInt(shapeAssets.length)]));
        _rightAssetsByQuestion.putIfAbsent(
            i,
            () => List.generate(questions[i].compareNumber2,
                (_) => shapeAssets[_random.nextInt(shapeAssets.length)]));
      }

      // If all answered, go to results
      if (selectedOptionIndices.length == questions.length) {
        return _navigateToResult();
      }

      if (currentIndex >= questions.length) {
        currentIndex = questions.length - 1;
      }
      _initCurrentQuestionState();
      setState(() => isLoading = false);
    } catch (e) {
      print("Error fetching questions: $e");
      setState(() => isLoading = false);
    }
  }

  void _initCurrentQuestionState() {
    if (selectedOptionIndices.containsKey(currentIndex)) {
      _pendingSelectedIndex = selectedOptionIndices[currentIndex];
      _hasSubmittedCurrent = true;
      _currentIsCorrect =
          questions[currentIndex].options[_pendingSelectedIndex!].isCorrect;
    } else {
      _pendingSelectedIndex = null;
      _hasSubmittedCurrent = false;
      _currentIsCorrect = false;
    }
  }

  void _showInstructionsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(widget.isHindi ? "निर्देश" : "Instructions"),
          content: Text(widget.isHindi
              ? "१. दिखाए गए आकृतियों की संख्या की तुलना करें।\n"
                  "२. किसी एक विकल्प को चुनने के लिए उस पर टैप करें (नीली सीमा दिखाई देगी)।\n"
                  "३. अपना उत्तर लॉक करने के लिए जमा करें पर टैप करें।\n"
                  "४. यदि उत्तर सही है, तो हरे रंग का टिक चिन्ह दिखाई देगा; यदि गलत है, तो लाल क्रॉस दिखाई देगा।\n"
                  "५. अगले और पिछले प्रश्नों पर जाने के लिए अगला और पिछला का उपयोग करें।\n"
                  "६. प्रगति स्वतः सहेजी जाती है।"
              : "1. Compare the number of shapes shown.\n"
                  "2. Tap one option to select it (blue border appears).\n"
                  "3. Tap Submit to lock in your answer.\n"
                  "4. If correct, a green tick appears; if wrong, a red cross appears.\n"
                  "5. Use Next and Previous to navigate.\n"
                  "6. Progress is saved automatically."),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(widget.isHindi ? "ठीक है" : "Got it!"),
            ),
          ],
        );
      },
    );
  }

  /// Builds a “grid” of images from a precomputed [assetList].
  /// Uses a Wrap so it expands to fit all images without internal scrolling.
  Widget _buildShapeGrid(List<String> assetList) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black54, width: 2),
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 5,
            spreadRadius: 1,
            offset: Offset(2, 2),
          )
        ],
      ),
      child: Wrap(
        spacing: 5,
        runSpacing: 5,
        children: assetList.map((assetPath) {
          return Image.asset(assetPath, width: 40, height: 40);
        }).toList(),
      ),
    );
  }

  void _selectOption(int optionIndex) {
    if (_hasSubmittedCurrent || selectedOptionIndices.containsKey(currentIndex))
      return;
    setState(() {
      _pendingSelectedIndex = optionIndex;
      // No scoring yet, only highlight border
    });
  }

  void _submitAnswer() {
    if (_hasSubmittedCurrent || _pendingSelectedIndex == null) return;
    bool isCorrect =
        questions[currentIndex].options[_pendingSelectedIndex!].isCorrect;
    setState(() {
      _hasSubmittedCurrent = true;
      _currentIsCorrect = isCorrect;
      selectedOptionIndices[currentIndex] = _pendingSelectedIndex!;
      if (isCorrect) {
        score++;
        correctCount++;
      } else {
        incorrectCount++;
      }
    });
    _saveGameState();
  }

  void _goToNextQuestion() {
    if (!_hasSubmittedCurrent &&
        !selectedOptionIndices.containsKey(currentIndex)) return;
    if (currentIndex < questions.length - 1) {
      setState(() {
        currentIndex++;
      });
      _initCurrentQuestionState();
      _saveGameState();
    } else {
      _navigateToResult();
    }
  }

  void _goToPreviousQuestion() {
    if (currentIndex > 0) {
      setState(() {
        currentIndex--;
      });
      _initCurrentQuestionState();
      _saveGameState();
    }
  }

  void _navigateToResult() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResultPage(
          gameTitle: widget.gameTitle,
          score: score,
          correctCount: correctCount,
          incorrectCount: incorrectCount,
          isHindi: widget.isHindi,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _saveGameState();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (questions.isEmpty) {
      return const Scaffold(
        body: Center(child: Text("No Compare questions available.")),
      );
    }
    final currentQuestion = questions[currentIndex];

    // Retrieve the precomputed asset lists for this question index
    final leftAssets = _leftAssetsByQuestion[currentIndex]!;
    final rightAssets = _rightAssetsByQuestion[currentIndex]!;

    return Scaffold(
      backgroundColor: Colors.lightBlue[50],
      appBar: AppBar(
        title: Text(
          widget.isHindi ? "तुलना" : "Compare",
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue.shade300,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, size: 30),
            onPressed: _showInstructionsDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                widget.isHindi
                    ? "सही चिन्ह चुनें:\nबाएँ ______ दाएँ"
                    : "Choose the correct sign:\nLeft _______ Right",
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Use Expanded-like behavior by wrapping both in a Row with equal space
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left container: uses its list of assets
                  Expanded(
                    child: _buildShapeGrid(leftAssets),
                  ),
                  const SizedBox(width: 10),
                  // Right container: uses its list of assets
                  Expanded(
                    child: _buildShapeGrid(rightAssets),
                  ),
                ],
              ),

              const SizedBox(height: 15),

              // Options list
              Column(
                children:
                    List.generate(currentQuestion.options.length, (index) {
                  final option = currentQuestion.options[index];
                  bool isPending = _pendingSelectedIndex == index;
                  bool showResult =
                      _hasSubmittedCurrent && _pendingSelectedIndex == index;
                  bool isCorrect = option.isCorrect;
                  Color borderColor = Colors.grey;
                  if (isPending && !_hasSubmittedCurrent) {
                    borderColor = Colors.blue;
                  } else if (showResult) {
                    borderColor = isCorrect ? Colors.green : Colors.red;
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: OptionTile(
                      text: option.title,
                      borderColor: borderColor,
                      overlayIcon: showResult
                          ? Icon(
                              isCorrect ? Icons.check_circle : Icons.cancel,
                              color: isCorrect ? Colors.green : Colors.red,
                              size: 50,
                            )
                          : null,
                      onTap: _hasSubmittedCurrent ||
                              selectedOptionIndices.containsKey(currentIndex)
                          ? null
                          : () => _selectOption(index),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 15),
              Center(
                child: Column(
                  children: [
                    Text(
                      widget.isHindi ? "अंक: $score" : "Score: $score",
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      widget.isHindi
                          ? "सही: $correctCount | गलत: $incorrectCount"
                          : "Correct: $correctCount | Incorrect: $incorrectCount",
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: currentIndex > 0 ? _goToPreviousQuestion : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          currentIndex > 0 ? Colors.orange : Colors.grey,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                    ),
                    child: Text(
                      widget.isHindi ? "पिछला" : "Previous",
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                  ElevatedButton(
                    onPressed:
                        (_pendingSelectedIndex != null && !_hasSubmittedCurrent)
                            ? _submitAnswer
                            : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                    ),
                    child: Text(
                      widget.isHindi ? "जमा करें" : "Submit",
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: (_hasSubmittedCurrent ||
                            selectedOptionIndices.containsKey(currentIndex))
                        ? _goToNextQuestion
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                    ),
                    child: Text(
                      widget.isHindi ? "अगला" : "Next",
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// OptionTile widget: a clickable option with border and optional overlay icon.
class OptionTile extends StatelessWidget {
  final String text;
  final Color borderColor;
  final Widget? overlayIcon;
  final VoidCallback? onTap;

  const OptionTile({
    Key? key,
    required this.text,
    required this.borderColor,
    this.overlayIcon,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: borderColor, width: 4),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
            ),
          ),
          if (overlayIcon != null)
            Positioned(
              right: 10,
              top: 10,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 1.0, sigmaY: 1.0),
                  child: Container(
                    color: Colors.transparent,
                    child: overlayIcon,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Model for a Compare question.
class CompareQuestion {
  final int compareNumber1;
  final int compareNumber2;
  final List<CompareOption> options;
  final String text;

  CompareQuestion({
    required this.compareNumber1,
    required this.compareNumber2,
    required this.options,
    required this.text,
  });
}

// Model for an option.
class CompareOption {
  final String title;
  final bool isCorrect;

  CompareOption({
    required this.title,
    required this.isCorrect,
  });

  factory CompareOption.fromMap(Map<String, dynamic> map) {
    return CompareOption(
      title: map['title'] ?? '',
      isCorrect: map['isCorrect'] ?? false,
    );
  }
}
