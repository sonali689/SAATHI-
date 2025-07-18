import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:translator_plus/translator_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'services/firestore_service.dart';
import 'package:http/http.dart' as http;

import 'navbar.dart';
import 'menu_bar.dart';
import 'language_notifier.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({Key? key}) : super(key: key);

  @override
  _AdminHomePageState createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final GoogleTranslator translator = GoogleTranslator();
  String appBarTitle = 'Admin Panel';

  // Admin Dashboard variables
  String? selectedCategory;
  String questionText = "";
  String questionImageUrl = "";
  // For Compare category: two number fields
  String compareNumber1 = "";
  String compareNumber2 = "";
  // For Let us Count category: one string field (no longer restricted to integers)
  String letUsCountNumber = "";
  // The answer options remain the same for all game types.
  List<AnswerOption> answerOptions = [];

  @override
  void initState() {
    super.initState();
    answerOptions.add(AnswerOption());
    _updateTranslations();
  }

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
        final result = await translator.translate('Admin Panel', to: 'hi');
        setState(() {
          appBarTitle = result.text;
        });
      } catch (e) {
        setState(() {
          appBarTitle = 'Admin Panel';
        });
      }
    } else {
      setState(() {
        appBarTitle = 'Admin Panel';
      });
    }
  }

  void addAnswerOption() {
    setState(() {
      answerOptions.add(AnswerOption());
    });
  }

  void removeAnswerOption(int index) {
    setState(() {
      answerOptions.removeAt(index);
    });
  }

  Future<void> saveQuestion() async {
    if (selectedCategory == null ||
        (questionText.isEmpty &&
            selectedCategory != "Compare" &&
            selectedCategory != "Let us Count" &&
            selectedCategory != "तुलना" &&
            selectedCategory != "चलो गिनें")) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                "Please select a category and enter the required question details.")),
      );
      return;
    }

    try {
      final firestoreService = FirestoreService();

      await firestoreService.saveQuestion(
        category: selectedCategory!,
        questionText: questionText,
        // For question types that need an image.
        questionImageUrl: (selectedCategory == "Guess the Letter" ||
                selectedCategory == "Left Middle Right" ||
                selectedCategory == "Shape Knowledge" ||
                selectedCategory == "अक्षर ज्ञान" ||
                selectedCategory == "बाएँ दाएँ मध्य" ||
                selectedCategory == "आकार ज्ञान")
            ? questionImageUrl
            : null,
        answerOptions: answerOptions.map((option) => option.toMap()).toList(),
        compareNumber1:
            selectedCategory == "Compare" || selectedCategory == "तुलना"
                ? compareNumber1
                : null,
        compareNumber2:
            selectedCategory == "Compare" || selectedCategory == "तुलना"
                ? compareNumber2
                : null,
        letUsCountNumber: selectedCategory == "Let us Count" ||
                selectedCategory == "चलो गिनें"
            ? letUsCountNumber
            : null,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Question saved successfully!")),
      );

      // Reset form after saving
      setState(() {
        selectedCategory = null;
        questionText = "";
        questionImageUrl = "";
        compareNumber1 = "";
        compareNumber2 = "";
        letUsCountNumber = "";
        answerOptions = [AnswerOption()];
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving question: $e")),
      );
    }
  }

  /// Helper function to upload an image to Imgur and return its URL.
  Future<String?> _uploadImageToImgur(XFile image) async {
    const clientId = '72c6c45319d3658';
    try {
      final fileBytes = await image.readAsBytes();
      final base64Image = base64Encode(fileBytes);
      final response = await http.post(
        Uri.parse('https://api.imgur.com/3/image'),
        headers: {'Authorization': 'Client-ID $clientId'},
        body: {'image': base64Image},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data']['link'];
      } else {
        throw Exception('Failed to upload image');
      }
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  /// For question types that require an image for the question
  Future<void> _chooseAndUploadImageForQuestion() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedImage =
        await picker.pickImage(source: ImageSource.gallery);
    if (pickedImage == null) return;

    final url = await _uploadImageToImgur(pickedImage);
    if (url != null) {
      setState(() {
        questionImageUrl = url;
      });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Image uploaded successfully!")));
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Image upload failed.")));
    }
  }

  Widget buildQuestionForm() {
    if (selectedCategory == null) return Container();

    switch (selectedCategory) {
      case "Name Picture Matching":
      case "नाम चित्र मिलान":
        return buildNamePictureMatchingForm();
      case "Guess the Letter":
      case "अक्षर ज्ञान":
        return buildGuessTheLetterForm();
      case "Compare":
      case "तुलना":
        return buildCompareForm();
      case "Let us Count":
      case "चलो गिनें":
        return buildLetUsCountForm();
      case "Left Middle Right":
      case "बाएँ दाएँ मध्य":
        return buildLeftOrRightForm();
      case "Shape Knowledge":
      case "आकार ज्ञान":
        return buildFitTheShapeForm();
      default:
        return buildDefaultForm();
    }
  }

  Widget buildNamePictureMatchingForm() {
    return Column(
      children: [
        buildTextField("Enter Question", (value) => questionText = value),
        ...answerOptions.map((option) => AnswerOptionWidget(
              option: option,
              onRemove: () => removeAnswerOption(answerOptions.indexOf(option)),
              uploadFunction: _uploadImageToImgur,
            )),
        buildAddOptionButton(),
      ],
    );
  }

  Widget buildGuessTheLetterForm() {
    return Column(
      children: [
        buildTextField("Enter Question", (value) => questionText = value),
        ElevatedButton.icon(
          onPressed: _chooseAndUploadImageForQuestion,
          icon: Icon(Icons.photo),
          label:
              Text(questionImageUrl.isEmpty ? "Choose Image" : "Change Image"),
        ),
        if (questionImageUrl.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Image.network(
              questionImageUrl,
              height: 150,
            ),
          ),
        ...answerOptions.map((option) => AnswerOptionWidget(
              option: option,
              onRemove: () => removeAnswerOption(answerOptions.indexOf(option)),
              uploadFunction: _uploadImageToImgur,
            )),
        buildAddOptionButton(),
      ],
    );
  }

  Widget buildCompareForm() {
    return Column(
      children: [
        buildNumberField(
            "Enter First Number", (value) => compareNumber1 = value),
        buildNumberField(
            "Enter Second Number", (value) => compareNumber2 = value),
        ...answerOptions.map((option) => AnswerOptionWidget(
              option: option,
              onRemove: () => removeAnswerOption(answerOptions.indexOf(option)),
              uploadFunction: _uploadImageToImgur,
            )),
        buildAddOptionButton(),
      ],
    );
  }

  // Updated Let Us Count form: using a text field instead of a number-only field
  Widget buildLetUsCountForm() {
    return Column(
      children: [
        buildTextField("Enter Question", (value) => questionText = value),
        buildTextField(
            "Enter Count Value", (value) => letUsCountNumber = value),
        ...answerOptions.map((option) => AnswerOptionWidget(
              option: option,
              onRemove: () => removeAnswerOption(answerOptions.indexOf(option)),
              uploadFunction: _uploadImageToImgur,
            )),
        buildAddOptionButton(),
      ],
    );
  }

  Widget buildLeftOrRightForm() {
    return Column(
      children: [
        buildTextField("Enter Question", (value) => questionText = value),
        ElevatedButton.icon(
          onPressed: _chooseAndUploadImageForQuestion,
          icon: Icon(Icons.photo),
          label:
              Text(questionImageUrl.isEmpty ? "Choose Image" : "Change Image"),
        ),
        if (questionImageUrl.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Image.network(
              questionImageUrl,
              height: 150,
            ),
          ),
        ...answerOptions.map((option) => AnswerOptionWidget(
              option: option,
              onRemove: () => removeAnswerOption(answerOptions.indexOf(option)),
              uploadFunction: _uploadImageToImgur,
            )),
        buildAddOptionButton(),
      ],
    );
  }

  /// New Game Type: Fit the Shape
  Widget buildFitTheShapeForm() {
    return Column(
      children: [
        // For Fit the Shape, the question includes an image.
        buildTextField("Enter Question", (value) => questionText = value),
        ElevatedButton.icon(
          onPressed: _chooseAndUploadImageForQuestion,
          icon: Icon(Icons.photo),
          label:
              Text(questionImageUrl.isEmpty ? "Choose Image" : "Change Image"),
        ),
        if (questionImageUrl.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Image.network(
              questionImageUrl,
              height: 150,
            ),
          ),
        // Answer options are handled same as others.
        ...answerOptions.map((option) => AnswerOptionWidget(
              option: option,
              onRemove: () => removeAnswerOption(answerOptions.indexOf(option)),
              uploadFunction: _uploadImageToImgur,
            )),
        buildAddOptionButton(),
      ],
    );
  }

  Widget buildDefaultForm() {
    return Column(
      children: [
        buildTextField("Enter Question", (value) => questionText = value),
        ...answerOptions.map((option) => AnswerOptionWidget(
              option: option,
              onRemove: () => removeAnswerOption(answerOptions.indexOf(option)),
              uploadFunction: _uploadImageToImgur,
            )),
        buildAddOptionButton(),
      ],
    );
  }

  Widget buildTextField(String label, Function(String) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        onChanged: onChanged,
        decoration:
            InputDecoration(labelText: label, border: OutlineInputBorder()),
      ),
    );
  }

  Widget buildNumberField(String label, Function(String) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        keyboardType: TextInputType.number,
        onChanged: onChanged,
        decoration:
            InputDecoration(labelText: label, border: OutlineInputBorder()),
      ),
    );
  }

  Widget buildAddOptionButton() {
    return ElevatedButton.icon(
      onPressed: addAnswerOption,
      icon: Icon(Icons.add),
      label: Text("Add Option"),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isHindi = Provider.of<LanguageNotifier>(context).isHindi;
    return Scaffold(
      appBar: NavBar(
  
        isHindi: isHindi,
        onToggleLanguage: (value) {
          Provider.of<LanguageNotifier>(context, listen: false)
              .toggleLanguage(value);
          _updateTranslations();
        },
        showMenuButton: true,
      ),
      drawer: CustomMenuBar(isHindi: isHindi,),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Select Category:",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              DropdownButton<String>(
                value: selectedCategory,
                isExpanded: true,
                hint: Text("Choose Category"),
                items: [
                  "Name Picture Matching",
                  "Guess the Letter",
                  "Compare",
                  "Let us Count",
                  "Left Middle Right",
                  "Shape Knowledge",
                  "Number Name Matching",
                  "Name Number Matching",
                  "Let us Tell Time",
                  "Alphabet Knowledge",
  
                  "नाम चित्र मिलान",
                  "अक्षर ज्ञान",
                  "तुलना",
                  "चलो गिनें",
                  "संख्या नाम मिलान",
                  "नाम संख्या मिलान",
                  "चलो समय बताएँ",
                  "वर्णमाला ज्ञान",
                  "बाएँ दाएँ मध्य",
                  "आकार ज्ञान",
                ]
                    .map((type) =>
                        DropdownMenuItem(value: type, child: Text(type)))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedCategory = value;
                    // Reset variables when category changes.
                    questionText = "";
                    questionImageUrl = "";
                    compareNumber1 = "";
                    compareNumber2 = "";
                    letUsCountNumber = "";
                    answerOptions = [AnswerOption()];
                  });
                },
              ),
              SizedBox(height: 16),
              buildQuestionForm(),
              SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: saveQuestion,
                  child: Text("Save",
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF078FFE),
                      padding:
                          EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AnswerOption {
  String title = "";
  String description = "";
  String imageUrl = "";
  bool isCorrect = false;

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'imageUrl': imageUrl.isNotEmpty ? imageUrl : null,
      'isCorrect': isCorrect,
    };
  }
}

class AnswerOptionWidget extends StatefulWidget {
  final AnswerOption option;
  final VoidCallback onRemove;
  final Future<String?> Function(XFile image) uploadFunction;

  const AnswerOptionWidget({
    Key? key,
    required this.option,
    required this.onRemove,
    required this.uploadFunction,
  }) : super(key: key);

  @override
  _AnswerOptionWidgetState createState() => _AnswerOptionWidgetState();
}

class _AnswerOptionWidgetState extends State<AnswerOptionWidget> {
  Future<void> _chooseAndUploadImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedImage =
        await picker.pickImage(source: ImageSource.gallery);
    if (pickedImage == null) return;

    final url = await widget.uploadFunction(pickedImage);
    if (url != null) {
      setState(() {
        widget.option.imageUrl = url;
      });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Option image uploaded successfully!")));
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Option image upload failed.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            TextField(
              onChanged: (value) => widget.option.title = value,
              decoration: InputDecoration(labelText: "Title"),
            ),
            SizedBox(height: 8),
            TextField(
              onChanged: (value) => widget.option.description = value,
              decoration: InputDecoration(labelText: "Description"),
            ),
            SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _chooseAndUploadImage,
              icon: Icon(Icons.photo),
              label: Text(widget.option.imageUrl.isEmpty
                  ? "Choose Option Image"
                  : "Change Option Image"),
            ),
            if (widget.option.imageUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Image.network(
                  widget.option.imageUrl,
                  height: 100,
                ),
              ),
            SizedBox(height: 8),
            Row(
              children: [
                Checkbox(
                  value: widget.option.isCorrect,
                  onChanged: (value) {
                    setState(() {
                      widget.option.isCorrect = value ?? false;
                    });
                  },
                ),
                Text("If this option is correct")
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                    icon: Icon(Icons.delete), onPressed: widget.onRemove),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
