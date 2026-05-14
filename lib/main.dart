import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'services/firestore_service.dart';
import 'services/auth_service.dart';
import 'firebase_options.dart';
import 'scoring_view.dart';
import 'history_view.dart';
import 'course_view.dart';
import 'login_page.dart';

class SavedCourse {
  final String? id;
  final String name;
  final int numHoles;
  final List<int> parValues;
  final List<int> distanceValues;

  SavedCourse({
    this.id,
    required this.name,
    required this.numHoles,
    required this.parValues,
    required this.distanceValues,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'numHoles': numHoles,
        'parValues': parValues,
        'distanceValues': distanceValues,
      };

  factory SavedCourse.fromJson(Map<String, dynamic> json, {String? id}) =>
      SavedCourse(
        id: id,
        name: json['name'] as String,
        numHoles: json['numHoles'] as int,
        parValues: List<int>.from(json['parValues'] as List<dynamic>),
        distanceValues: List<int>.from(json['distanceValues'] as List<dynamic>),
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SavedCourse &&
        other.id == id &&
        other.name == name &&
        other.numHoles == numHoles &&
        listEquals(other.parValues, parValues) &&
        listEquals(other.distanceValues, distanceValues);
  }

  @override
  int get hashCode => Object.hash(id, name, numHoles, Object.hashAll(parValues),
      Object.hashAll(distanceValues));
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FirebaseAppCheck.instance.activate(
      webProvider: ReCaptchaEnterpriseProvider('6LdGEuIsAAAAAPL7eZsMGE6E8hFVFfutfoXpRY5u'),
    );
  } catch (e) {
    if (kDebugMode) {
      debugPrint('Firebase initialization failed: $e');
    }
  }
  runApp(const FrisbeeDemoApp());
}

class FrisbeeDemoApp extends StatefulWidget {
  const FrisbeeDemoApp({super.key});

  @override
  State<FrisbeeDemoApp> createState() => _FrisbeeDemoAppState();
}

class _FrisbeeDemoAppState extends State<FrisbeeDemoApp> {
  final AuthService _authService = AuthService();
  bool _isAuthenticated = false;
  bool _checkingAuth = true;

  @override
  void initState() {
    super.initState();
    _checkExistingSession();
  }

  /// On app start, check if the user already has a valid Firebase session
  /// AND is still on the allowlist.
  Future<void> _checkExistingSession() async {
    final user = _authService.currentUser;
    if (user != null && user.email != null) {
      final allowed = await _authService.isAllowlisted(user.email!);
      if (allowed) {
        setState(() {
          _isAuthenticated = true;
          _checkingAuth = false;
        });
        return;
      } else {
        await _authService.signOut();
      }
    }
    setState(() => _checkingAuth = false);
  }

  void _onLoginSuccess() {
    setState(() => _isAuthenticated = true);
  }

  Future<void> _onSignOut() async {
    await _authService.signOut();
    if (mounted) {
      setState(() => _isAuthenticated = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Frisbee Scoring App',
      theme: ThemeData(primarySwatch: Colors.orange),
      home: _checkingAuth
          ? const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            )
          : _isAuthenticated
              ? FrisbeeDemoPage(onSignOut: _onSignOut)
              : LoginPage(onLoginSuccess: _onLoginSuccess),
    );
  }
}

class FrisbeeDemoPage extends StatefulWidget {
  final Future<void> Function() onSignOut;

  const FrisbeeDemoPage({super.key, required this.onSignOut});

  @override
  State<FrisbeeDemoPage> createState() => _FrisbeeDemoPageState();
}

class _FrisbeeDemoPageState extends State<FrisbeeDemoPage> {
  static const String _kAddNewCourseOptionId = '__add_new_course__';

  int _selectedIndex = 0;
  bool _isSigningOut = false;
  int _courseDropdownResetVersion = 0;
  int numPlayers = 2;
  int numHoles = 9;
  List<List<String>> scores = [];
  List<String> playerNames = [];
  List<int> parValues = [];
  List<int> distanceValues = [];
  int parDefault = 3;
  String courseName = '';
  int _gameSessionVersion = 0;
  int _initialHoleForActiveGame = 0;
  String? _activeGameId;
  final List<TextEditingController> _nameControllers = [];
  final List<TextEditingController> _parControllers = [];
  final List<TextEditingController> _distanceControllers = [];
  final TextEditingController _courseNameController = TextEditingController();

  // Firestore integration
  late final FirestoreService _firestoreService;
  List<GameHistory> gameHistory = [];
  List<SavedCourse> savedCourses = [];
  SavedCourse? selectedCourse;

  static const String _kSavedNamesKey = 'saved_player_names_v1';
  // static const String _kGameHistoryKey = 'game_history_v1'; // Deprecated
  static const String _kCourseNameKey = 'saved_course_name_v1';

  @override
  void initState() {
    super.initState();
    // Initialize Firestore with the current user's UID for per-user data
    final user = AuthService().currentUser;
    _firestoreService = FirestoreService(uid: user!.uid);
    _ensureControllers(numPlayers);
    _loadSavedNames();
    _ensureParControllers(numHoles);
    _ensureDistanceControllers(numHoles);
    _setupFirestoreListeners();
    _loadSavedCourseName();
  }

  void _setupFirestoreListeners() {
    _firestoreService.getGames().listen((games) {
      if (mounted) {
        setState(() {
          gameHistory = games;
        });
      }
    });

    _firestoreService.getCourses().listen((courses) {
      if (mounted) {
        setState(() {
          savedCourses = courses;
        });
      }
    });
  }

  void _ensureControllers(int count) {
    while (_nameControllers.length < count) {
      final c = TextEditingController();
      c.addListener(() {
        _saveNames();
      });
      _nameControllers.add(c);
    }
    while (_nameControllers.length > count) {
      _nameControllers.removeLast().dispose();
    }
  }

  Future<void> _loadSavedNames() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_kSavedNamesKey);
      if (saved == null || saved.isEmpty) return;
      _ensureControllers(numPlayers);
      for (int i = 0; i < _nameControllers.length; i++) {
        if (i < saved.length && saved[i].isNotEmpty) {
          _nameControllers[i].text = saved[i];
        }
      }
      setState(() {});
    } catch (e) {
      // ignore errors
    }
  }

  Future<void> _saveNames() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final names = List<String>.generate(numPlayers, (i) {
        final txt =
            i < _nameControllers.length ? _nameControllers[i].text.trim() : '';
        return txt;
      });
      await prefs.setStringList(_kSavedNamesKey, names);
    } catch (e) {
      // ignore save errors
    }
  }

  Future<void> _loadSavedCourseName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_kCourseNameKey);
      if (saved == null || saved.isEmpty) return;
      _courseNameController.text = saved;
      setState(() {
        courseName = saved;
      });
    } catch (e) {
      // ignore errors
    }
  }

  Future<void> _saveCourseName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCourseNameKey, _courseNameController.text.trim());
    } catch (e) {
      // ignore save errors
    }
  }

  void _ensureParControllers(int count) {
    while (_parControllers.length < count) {
      final c = TextEditingController(text: parDefault.toString());
      _parControllers.add(c);
    }
    while (_parControllers.length > count) {
      _parControllers.removeLast().dispose();
    }
  }

  void _ensureDistanceControllers(int count) {
    while (_distanceControllers.length < count) {
      final c = TextEditingController();
      _distanceControllers.add(c);
    }
    while (_distanceControllers.length > count) {
      _distanceControllers.removeLast().dispose();
    }
  }

  Future<void> _saveCurrentGame() async {
    if (scores.isEmpty) return;

    final now = DateTime.now();
    final dateStr =
        '${now.month}/${now.day}/${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}';

    final game = GameHistory(
      date: dateStr,
      numPlayers: numPlayers,
      numHoles: numHoles,
      playerNames: List.from(playerNames),
      parValues: List.from(parValues),
      scores: scores.map((row) => List<String>.from(row)).toList(),
      courseName: courseName,
    );

    try {
      final didUpdate = _activeGameId != null;
      if (_activeGameId != null) {
        await _firestoreService.updateGame(_activeGameId!, game);
      } else {
        _activeGameId = await _firestoreService.saveGame(game);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(didUpdate ? 'Game updated in cloud!' : 'Game saved to cloud!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving game: $e')),
        );
      }
    }
  }

  void _deleteGame(int index) {
    final game = gameHistory[index];
    if (game.id != null) {
      _firestoreService.deleteGame(game.id!);
      if (_activeGameId == game.id) {
        _activeGameId = null;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Game deleted')),
      );
    } else {
      // Fallback for local-only games if existing (though we replaced the list)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete local-only game')),
      );
    }
  }

  int _findFirstUnfinishedHole(List<List<String>> gameScores, int holes, int players) {
    for (int h = 0; h < holes; h++) {
      for (int p = 0; p < players; p++) {
        final row = p < gameScores.length ? gameScores[p] : <String>[];
        if (h >= row.length) {
          return h;
        }
        final score = row[h].trim();
        if (score.isEmpty || int.tryParse(score) == null) {
          return h;
        }
      }
    }
    return holes > 0 ? holes - 1 : 0;
  }

  void _continueGame(GameHistory game) {
    setState(() {
      _activeGameId = game.id;
      numPlayers = game.numPlayers;
      numHoles = game.numHoles;
      _ensureControllers(numPlayers);
      _ensureParControllers(numHoles);
      _ensureDistanceControllers(numHoles);

      playerNames = List<String>.generate(numPlayers, (i) {
        final name =
            i < game.playerNames.length ? game.playerNames[i].trim() : '';
        return name.isNotEmpty ? name : 'Player ${i + 1}';
      });
      for (int i = 0; i < numPlayers; i++) {
        _nameControllers[i].text = playerNames[i];
      }

      parValues = List<int>.generate(numHoles, (i) {
        return i < game.parValues.length ? game.parValues[i] : 3;
      });
      for (int i = 0; i < numHoles; i++) {
        _parControllers[i].text = parValues[i].toString();
      }

      scores = List<List<String>>.generate(
        numPlayers,
        (p) => List<String>.generate(numHoles, (h) {
          if (p < game.scores.length && h < game.scores[p].length) {
            return game.scores[p][h];
          }
          return '';
        }),
      );

      courseName = game.courseName;
      _courseNameController.text = game.courseName;
      selectedCourse = savedCourses.where((course) {
        return course.name == game.courseName && course.numHoles == game.numHoles;
      }).firstOrNull;

      distanceValues = List<int>.generate(numHoles, (i) {
        if (selectedCourse != null && i < selectedCourse!.distanceValues.length) {
          return selectedCourse!.distanceValues[i];
        }
        return 0;
      });
      for (int i = 0; i < numHoles; i++) {
        _distanceControllers[i].text =
            distanceValues[i] == 0 ? '' : distanceValues[i].toString();
      }

      _initialHoleForActiveGame =
          _findFirstUnfinishedHole(scores, numHoles, numPlayers);
      _gameSessionVersion++;
      _selectedIndex = 2;
    });
  }

  void _startGame() {
    setState(() {
      _activeGameId = null;
      scores = List.generate(numPlayers, (_) => List.filled(numHoles, ""));
      playerNames = List.generate(numPlayers, (i) {
        final txt =
            _nameControllers.length > i ? _nameControllers[i].text.trim() : '';
        return txt.isNotEmpty ? txt : 'Player ${i + 1}';
      });
      parValues = List.generate(
          numHoles,
          (i) => i < _parControllers.length
              ? int.tryParse(_parControllers[i].text) ?? 3
              : 3);
      distanceValues = List.generate(
          numHoles,
          (i) => i < _distanceControllers.length
              ? int.tryParse(_distanceControllers[i].text) ?? 0
              : 0);
      courseName = _courseNameController.text.trim();
      _initialHoleForActiveGame = 0;
      _gameSessionVersion++;
      _selectedIndex = 2; // Navigate to Game tab
    });
    _saveNames();
    _saveCourseName();
  }

  void _onRestart() {
    setState(() {
      _activeGameId = null;
      scores = [];
      _selectedIndex = 0; // Return to Home tab
    });
  }

  void _onNumPlayersChanged(int newValue) {
    setState(() {
      numPlayers = newValue;
      _ensureControllers(numPlayers);
    });
  }

  void _onCourseSelected(SavedCourse? course) {
    if (course?.id == _kAddNewCourseOptionId) {
      setState(() {
        selectedCourse = null;
        _courseDropdownResetVersion++;
        _selectedIndex = 1; // Navigate to Course tab
      });
      return;
    }

    if (course == null) {
      setState(() {
        selectedCourse = null;
        courseName = '';
        _courseNameController.clear();
        _ensureParControllers(numHoles);
        _ensureDistanceControllers(numHoles);
        for (final controller in _parControllers) {
          controller.clear();
        }
        for (final controller in _distanceControllers) {
          controller.clear();
        }
      });
      return;
    }

    setState(() {
      selectedCourse = course;
      courseName = course.name;
      _courseNameController.text = course.name;
      numHoles = course.numHoles;
      _ensureParControllers(numHoles);
      _ensureDistanceControllers(numHoles);

      // Populate par and distance values
      for (int i = 0; i < course.numHoles; i++) {
        if (i < _parControllers.length) {
          _parControllers[i].text = course.parValues[i].toString();
        }
        if (i < _distanceControllers.length) {
          _distanceControllers[i].text = course.distanceValues[i].toString();
        }
      }
    });
  }

  void _onCoursesUpdated(List<SavedCourse> courses) {
    // Check for added course
    if (courses.length > savedCourses.length) {
      // New course added
      _firestoreService.saveCourse(courses.last);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Course saved to cloud!')),
      );
    } else if (courses.length == savedCourses.length) {
      // Check for updates
      for (int i = 0; i < courses.length; i++) {
        final newCourse = courses[i];
        final oldCourse = savedCourses[i];

        // If they differ and have an ID, update it
        if (newCourse != oldCourse && newCourse.id != null) {
          _firestoreService.updateCourse(newCourse);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Course updated in cloud!')),
          );
        }
      }
    }

    setState(() {
      savedCourses = courses;
      // Update selectedCourse reference to match the new list
      if (selectedCourse != null) {
        selectedCourse = courses.firstWhere(
          (course) =>
              course.name == selectedCourse!.name &&
              course.numHoles == selectedCourse!.numHoles,
          orElse: () => selectedCourse!, // Keep old reference if not found
        );
      }
    });
  }

  void _onCourseEdited(String oldCourseName, String newCourseName) {
    // When a course is edited, version all games in history that use the old course name
    // Find the next version letter for this course
    String versionLetter = _getNextVersionLetter(oldCourseName);

    // Clear selected course to avoid dropdown conflicts
    setState(() {
      selectedCourse = null;
      _courseNameController.clear();
      courseName = '';
    });

    // Update all games in history that have the old course name
    bool historyUpdated = false;
    for (final game in gameHistory) {
      if (game.courseName == oldCourseName && game.id != null) {
        final updatedGame = GameHistory(
          id: game.id,
          date: game.date,
          numPlayers: game.numPlayers,
          numHoles: game.numHoles,
          playerNames: game.playerNames,
          parValues: game.parValues,
          scores: game.scores,
          courseName: '$oldCourseName $versionLetter',
        );
        _firestoreService.updateGame(game.id!, updatedGame);
        historyUpdated = true;
      }
    }

    if (historyUpdated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Previous "$oldCourseName" games versioned as "$oldCourseName $versionLetter"')),
      );
    }
  }

  String _getNextVersionLetter(String baseName) {
    // Find all existing versions in history
    Set<String> existingVersions = {};
    for (var game in gameHistory) {
      if (game.courseName.startsWith(baseName)) {
        existingVersions.add(game.courseName);
      }
    }

    // Find the next available letter (A, B, C, etc.)
    String letter = 'A';
    while (existingVersions.contains('$baseName $letter')) {
      letter = String.fromCharCode(letter.codeUnitAt(0) + 1);
    }
    return letter;
  }

  void _onBottomNavTapped(int index) {
    // Only allow navigating to Game tab if game has started
    if (index == 2 && scores.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Start a game first!')),
      );
      return;
    }

    if (index == 0) {
      setState(() {
        _selectedIndex = 0;
      });
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _handleSignOut() async {
    setState(() => _isSigningOut = true);
    try {
      await widget.onSignOut();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign out failed. Please try again.')),
      );
      setState(() => _isSigningOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Frisbee Scoring App'),
        actions: [
          if (_isSigningOut)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              onPressed: _handleSignOut,
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          // Home tab: Setup screen
          _buildSetupScreen(),
          // Course tab
          CourseView(
            savedCourses: savedCourses,
            onCoursesUpdated: _onCoursesUpdated,
            onCourseEdited: _onCourseEdited,
          ),
          // Game tab: Scoring screen
          if (scores.isNotEmpty)
            ScoringView(
              key: ValueKey(_gameSessionVersion),
              numPlayers: numPlayers,
              numHoles: numHoles,
              initialHole: _initialHoleForActiveGame,
              scores: scores,
              playerNames: playerNames,
              parValues: parValues,
              distanceValues: distanceValues,
              courseName: courseName,
              gameHistory: gameHistory,
              onScoresChanged: (newScores) {
                setState(() {
                  scores = newScores;
                });
              },
              onRestart: _onRestart,
              onSave: _saveCurrentGame,
            )
          else
            const Center(child: Text('No active game')),
          // History tab
          HistoryView(
            history: gameHistory,
            onDelete: _deleteGame,
            onContinueGame: _continueGame,
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onBottomNavTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.golf_course),
            label: 'Course',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.sports_golf),
            label: 'Game',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
        ],
      ),
    );
  }

  Widget _buildSetupScreen() {
    return SingleChildScrollView(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('Select Game Options',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: SizedBox(
                width: double.infinity,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Select Course:',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      const Text(
                        'Select One Time Course and fill in the details below OR select a different Course from the Drop-Down List.',
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<SavedCourse>(
                        key: ValueKey(
                            'course_dropdown_${_courseDropdownResetVersion}_${selectedCourse?.id ?? 'custom'}'),
                        value: selectedCourse,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Choose a course or enter custom name',
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: [
                          const DropdownMenuItem<SavedCourse>(
                            value: null,
                            child: Text('One Time Course'),
                          ),
                          ...savedCourses.map((course) {
                            return DropdownMenuItem<SavedCourse>(
                              value: course,
                              child: Text(course.name),
                            );
                          }),
                          DropdownMenuItem<SavedCourse>(
                            value: SavedCourse(
                              id: _kAddNewCourseOptionId,
                              name: 'Add New Course',
                              numHoles: 0,
                              parValues: const [],
                              distanceValues: const [],
                            ),
                            child: const Text('Add New Course'),
                          ),
                        ],
                        onChanged: _onCourseSelected,
                      ),
                      if (selectedCourse == null) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _courseNameController,
                          maxLength: 30,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(30)
                          ],
                          decoration: const InputDecoration(
                            labelText: 'One Time Course Name',
                            border: OutlineInputBorder(),
                            counterText: '',
                          ),
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => _saveCourseName(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Players: '),
                DropdownButton<int>(
                  value: numPlayers,
                  items: [1, 2, 3, 4, 5, 6].map((int value) {
                    return DropdownMenuItem<int>(
                      value: value,
                      child: Text(value.toString()),
                    );
                  }).toList(),
                  onChanged: (int? newValue) {
                    if (newValue == null) return;
                    _onNumPlayersChanged(newValue);
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Center(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: List<Widget>.generate(
                    numPlayers,
                    (index) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: SizedBox(
                        width: 240,
                        child: TextFormField(
                          controller: _nameControllers[index],
                          maxLength: 15,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(15)
                          ],
                          decoration: InputDecoration(
                            labelText: 'Player ${index + 1} Name',
                            border: const OutlineInputBorder(),
                            counterText: '',
                          ),
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (selectedCourse == null) ...[
              const Text('Only for a One Time Course',
                  style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Holes: '),
                  DropdownButton<int>(
                    value: numHoles,
                    items: [9, 18].map((int value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text(value.toString()),
                      );
                    }).toList(),
                    onChanged: (int? newValue) {
                      setState(() {
                        numHoles = newValue!;
                        _ensureParControllers(numHoles);
                        _ensureDistanceControllers(numHoles);
                      });
                    },
                  ),
                  const SizedBox(width: 16),
                  const Text('Par Default: '),
                  DropdownButton<int>(
                    value: parDefault,
                    items: [3, 4, 5].map((int value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text(value.toString()),
                      );
                    }).toList(),
                    onChanged: (int? newValue) {
                      if (newValue == null) return;
                      setState(() {
                        parDefault = newValue;
                        for (int i = 0; i < _parControllers.length; i++) {
                          _parControllers[i].text = parDefault.toString();
                        }
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: List<Widget>.generate(numHoles, (index) {
                  final isCustomCourse = selectedCourse == null;
                  return SizedBox(
                    width: 100,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('H${index + 1}',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        // Par input
                        Row(
                          children: [
                            const SizedBox(
                                width: 30,
                                child: Text('Par:',
                                    style: TextStyle(fontSize: 11))),
                            const SizedBox(width: 4),
                            SizedBox(
                              width: 60,
                              height: 36,
                              child: TextFormField(
                                controller: _parControllers.length > index
                                    ? _parControllers[index]
                                    : null,
                                readOnly: !isCustomCourse,
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(1)
                                ],
                                onChanged: (value) {
                                  if (_parControllers.length <= index) return;
                                  final c = _parControllers[index];
                                  final v = int.tryParse(value);
                                  if (v == null) return;
                                  final clamped = v.clamp(2, 6);
                                  if (clamped != v) {
                                    c.text = clamped.toString();
                                    c.selection = TextSelection.collapsed(
                                        offset: c.text.length);
                                  }
                                },
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                      vertical: 8.0, horizontal: 8.0),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Distance input
                        Row(
                          children: [
                            const SizedBox(
                                width: 30,
                                child: Text('Dist:',
                                    style: TextStyle(fontSize: 11))),
                            const SizedBox(width: 4),
                            SizedBox(
                              width: 60,
                              height: 36,
                              child: TextFormField(
                                controller: _distanceControllers.length > index
                                    ? _distanceControllers[index]
                                    : null,
                                readOnly: !isCustomCourse,
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(4)
                                ],
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                      vertical: 8.0, horizontal: 8.0),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _startGame,
              child: const Text('Start Game'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final c in _nameControllers) {
      c.dispose();
    }
    for (final c in _parControllers) {
      c.dispose();
    }
    for (final c in _distanceControllers) {
      c.dispose();
    }
    _courseNameController.dispose();
    super.dispose();
  }
}
