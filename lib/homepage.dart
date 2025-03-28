import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'language_notifier.dart';
import 'navbar.dart';
import 'menu_bar.dart'; // Contains CustomMenuBar
import 'package:translator_plus/translator_plus.dart';
import 'game.dart'; // Import the Game Page
import 'compare.dart';
import 'letuscount.dart'; // Import the LetUsCount Page
import 'matching.dart'; // Import the Matching Page

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GoogleTranslator translator = GoogleTranslator();
  String appBarTitle = 'Saathi';
  String box1Text = 'Box 1';
  String box2Text = 'Guess the Letter';
  String box3Text = 'Compare';
  String box4Text = 'Let us Count';
  String box5Text = 'Number Name Matching';
  String box6Text = 'Name Number Matching';
  String box7Text = 'Let us Tell Time';
  String box8Text = 'Let us Look at Calendar';
  String box9Text = 'Alphabet Knowledge';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateTranslations();
  }

  Future<void> _updateTranslations() async {
    final isHindi =
        Provider.of<LanguageNotifier>(context, listen: false).isHindi;
    if (isHindi) {
      try {
        final results = await Future.wait([
          translator.translate('Saathi', to: 'hi'),
          translator.translate('Box 1', to: 'hi'),
          translator.translate('Guess the Letter', to: 'hi'),
          translator.translate('Compare', to: 'hi'),
          translator.translate('Number Name Matching', to: 'hi'),
          translator.translate('Name Number Matching', to: 'hi'),
          translator.translate('Let us Tell Time', to: 'hi'),
          translator.translate('Alphabet Knowledge', to: 'hi'),
        ]);
        setState(() {
          appBarTitle = results[0].text;
          box1Text = results[1].text;
          box2Text = results[2].text;
          box3Text = results[3].text;
          box4Text = 'Let us Count'; // You can translate if needed.
          box5Text = results[4].text;
          box6Text = results[5].text;
          box7Text = results[6].text;
          box8Text = 'Let us Look at Calendar'; // You can translate if needed.
          box9Text = results[7].text;
        });
      } catch (e) {
        // Fallback to English.
      }
    } else {
      setState(() {
        appBarTitle = 'Saathi';
        box1Text = 'Name Picture Mapping';
        box2Text = 'Guess the Letter';
        box3Text = 'Compare';
        box4Text = 'Let us Count';
        box5Text = 'Number Name Matching';
        box6Text = 'Name Number Matching';
        box7Text = 'Let us Tell Time';
        box8Text = 'Let us Look at Calendar';
        box9Text = 'Alphabet Knowledge';
      });
    }
  }

  // Helper method to navigate based on the box text
  void _navigateBasedOnText(String text) {
    Widget destination;
    if (text == "Compare") {
      destination = ComparePage(); // sample values; adjust as needed
    } else if (text == "Let us Count" || text == "Let us Tell Time" || text == "Let us Look at Calendar" || text== "Guess the Letter") {
      destination = LetUsCountPage();
    } else if (text == "Number Name Matching" || text == "Name Number Matching" || text == "Alphabet Knowledge") {
      destination = MatchingPage();
    }
    else {
      destination = GamePage(gameTitle: text);
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => destination),
    );
  }

  Widget buildBox(String text, String imagePath, Color bgColor) {
    return GestureDetector(
      onTap: () {
        _navigateBasedOnText(text);
      },
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        padding: const EdgeInsets.all(10),
        margin: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: Colors.black, width: 2),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(50),
                image: DecorationImage(
                  image: AssetImage(imagePath),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      _navigateBasedOnText(text);
                    },
                    child: const Text('Play'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isHindi = Provider.of<LanguageNotifier>(context).isHindi;
    return Scaffold(
      appBar: NavBar(
        title: appBarTitle,
        isHindi: isHindi,
        onToggleLanguage: (value) {
          Provider.of<LanguageNotifier>(context, listen: false)
              .toggleLanguage(value);
          _updateTranslations();
        },
        showMenuButton: true,
      ),
      drawer: const CustomMenuBar(),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              buildBox(box1Text, 'assets/image.png', Colors.blue.shade100),
              buildBox(box2Text, 'assets/image.png', Colors.blue.shade100),
              buildBox(box3Text, 'assets/image.png', Colors.blue.shade100),
              buildBox(box4Text, 'assets/image.png', Colors.blue.shade100),
              buildBox(box5Text, 'assets/image.png', Colors.blue.shade100),
              buildBox(box6Text, 'assets/image.png', Colors.blue.shade100),
              buildBox(box7Text, 'assets/image.png', Colors.blue.shade100),
              buildBox(box8Text, 'assets/image.png', Colors.blue.shade100),
              buildBox(box9Text, 'assets/image.png', Colors.blue.shade100),
            ],
          ),
        ),
      ),
    );
  }
}
