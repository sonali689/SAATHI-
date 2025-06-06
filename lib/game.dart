// unchanged imports
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'result.dart';

class GamePage extends StatefulWidget {
  final String gameTitle;

  const GamePage({Key? key, required this.gameTitle}) : super(key: key);

  @override
  _GamePageState createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  String questionText = "";
  String currentDocId = "";
  List<Map<String, dynamic>> options = [];

  int score = 0;
  int correctCount = 0;
  int incorrectCount = 0;
  Map<String, dynamic> userAnswers = {};

  List<String> questionOrder = [];
  List<QueryDocumentSnapshot> allQuestions = [];
  int currentQuestionIndex = 0;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  @override
  void initState() {
    super.initState();
    _loadGameState().then((_) => _fetchQuestionsInOrder());
  }

  Future<void> _loadGameState() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final snapshot = await _dbRef
          .child("users/${user.uid}/games/${widget.gameTitle}")
          .get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          score = data['score'] ?? 0;
          correctCount = data['correctCount'] ?? 0;
          incorrectCount = data['incorrectCount'] ?? 0;
          if (data['answers'] != null) {
            userAnswers = Map<String, dynamic>.from(data['answers']);
          }
          if (data['questionOrder'] != null) {
            questionOrder = List<String>.from(data['questionOrder']);
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
      await _dbRef.child("users/${user.uid}/games/${widget.gameTitle}").update({
        "score": score,
        "correctCount": correctCount,
        "incorrectCount": incorrectCount,
        "answers": userAnswers,
        "questionOrder": questionOrder,
      });
    } catch (e) {
      print("Error saving game state: $e");
    }
  }

  Future<void> _fetchQuestionsInOrder() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(widget.gameTitle)
          .get();

      Map<String, QueryDocumentSnapshot> questionMap = {
        for (var doc in snapshot.docs) doc.id: doc
      };

      if (questionOrder.isEmpty) {
        List<String> answered = [];
        List<String> unanswered = [];

        for (var doc in snapshot.docs) {
          if (userAnswers.containsKey(doc.id)) {
            answered.add(doc.id);
          } else {
            unanswered.add(doc.id);
          }
        }

        questionOrder = [...answered, ...unanswered];
        await _saveGameState();
      }

      // All questions answered? -> navigate to result directly.
      bool allAnswered =
      questionOrder.every((id) => userAnswers.containsKey(id));

      if (allAnswered) {
        _navigateToResult();
        return;
      }

      setState(() {
        allQuestions = questionOrder
            .map((id) => questionMap[id])
            .where((doc) => doc != null)
            .cast<QueryDocumentSnapshot>()
            .toList();

        int startIndex = answeredQuestionCount();
        _loadQuestionFromIndex(startIndex);
      });
    } catch (e) {
      print("Error fetching questions: $e");
    }
  }

  int answeredQuestionCount() {
    return questionOrder.indexWhere((id) => !userAnswers.containsKey(id));
  }

  void _loadQuestionFromIndex(int index) {
    if (index < 0 || index >= allQuestions.length) return;

    final doc = allQuestions[index];
    final data = doc.data() as Map<String, dynamic>;
    setState(() {
      currentQuestionIndex = index;
      currentDocId = doc.id;
      questionText = data['text'] ?? "Question";
      options = List<Map<String, dynamic>>.from(data['options'] ?? []);
      for (var opt in options) {
        opt['selected'] = false;
      }

      if (userAnswers.containsKey(doc.id)) {
        final savedAnswer = userAnswers[doc.id];
        final savedIndex = savedAnswer['selectedOptionIndex'] as int?;
        if (savedIndex != null && savedIndex < options.length) {
          options[savedIndex]['selected'] = true;
        }
      }
    });
  }

  void _goToPreviousQuestion() {
    if (currentQuestionIndex > 0) {
      _loadQuestionFromIndex(currentQuestionIndex - 1);
    }
  }

  void _goToNextQuestion() {
    if (currentQuestionIndex < allQuestions.length - 1) {
      _loadQuestionFromIndex(currentQuestionIndex + 1);
    } else {
      _navigateToResult();
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
        ),
      ),
    );
  }

  void checkAnswer(int index) {
    if (userAnswers.containsKey(currentDocId)) return;

    bool isCorrect = options[index]['isCorrect'] == true;

    setState(() {
      options[index]['selected'] = true;

      if (isCorrect) {
        score++;
        correctCount++;
      } else {
        incorrectCount++;
      }

      userAnswers[currentDocId] = {
        "selectedOptionIndex": index,
        "isCorrect": isCorrect,
      };
    });

    _saveGameState();
  }

  void showInstructions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Instructions"),
        content: Text(
          "1. Answered questions are listed first.\n"
              "2. You start at the first unanswered question.\n"
              "3. Navigate freely using Next/Previous.\n"
              "4. Answers are locked once selected.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Got it!"),
          ),
        ],
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
    return Scaffold(
      backgroundColor: Colors.lightBlue[50],
      appBar: AppBar(
        backgroundColor: Colors.blue.shade300,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(widget.gameTitle,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: Icon(Icons.info_outline, color: Colors.white),
              onPressed: () => showInstructions(context),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              questionText.isNotEmpty ? questionText : "Loading question...",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.builder(
                itemCount: options.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 15,
                  crossAxisSpacing: 15,
                ),
                itemBuilder: (context, index) {
                  var option = options[index];
                  bool isSelected = option['selected'] == true;
                  bool isCorrect = option['isCorrect'] == true;

                  return GestureDetector(
                    onTap: () {
                      if (!userAnswers.containsKey(currentDocId)) {
                        checkAnswer(index);
                      }
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            border: isSelected
                                ? Border.all(
                              color: isCorrect
                                  ? Colors.green
                                  : Colors.red,
                              width: 6,
                            )
                                : null,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.3),
                                blurRadius: 5,
                                spreadRadius: 2,
                              )
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Image.network(
                              option['imageUrl'],
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        if (isSelected && isCorrect)
                          Positioned(
                            bottom: 10,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                option['description'] ?? '',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 15),
            Column(
              children: [
                Text(
                  "Score: $score",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  "Correct: $correctCount | Incorrect: $incorrectCount",
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _goToPreviousQuestion,
                  child: Text("Previous",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange),
                ),
                ElevatedButton(
                  onPressed: _goToNextQuestion,
                  child: Text("Next",
                  style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.green,),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
