import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'main.dart';

class CourseView extends StatefulWidget {
  final List<SavedCourse> savedCourses;
  final Function(List<SavedCourse>) onCoursesUpdated;
  final Function(String oldName, String newName)? onCourseEdited;

  const CourseView({
    super.key,
    required this.savedCourses,
    required this.onCoursesUpdated,
    this.onCourseEdited,
  });

  @override
  State<CourseView> createState() => _CourseViewState();
}

class _CourseViewState extends State<CourseView> {
  static const double _compactLayoutBreakpoint = 900;
  final TextEditingController _courseNameController = TextEditingController();
  int numHoles = 9;
  final List<TextEditingController> _parControllers = [];
  final List<TextEditingController> _distanceControllers = [];
  final List<String?> _holeMapImages = [];
  final List<String?> _teeSignImages = [];
  final ImagePicker _imagePicker = ImagePicker();
  int? _editingCourseIndex;

  String _toJpegBase64(Uint8List sourceBytes) {
    final decoded = img.decodeImage(sourceBytes);
    if (decoded == null) {
      throw const FormatException('Unsupported image format');
    }
    final jpegBytes = img.encodeJpg(decoded, quality: 85);
    return base64Encode(jpegBytes);
  }

  Uint8List? _tryDecodeBase64(String value) {
    try {
      return base64Decode(value);
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _ensureControllers(numHoles);
  }

  void _ensureControllers(int count) {
    // Manage par controllers
    while (_parControllers.length < count) {
      _parControllers.add(TextEditingController(text: '3'));
    }
    while (_parControllers.length > count) {
      _parControllers.removeLast().dispose();
    }

    // Manage distance controllers
    while (_distanceControllers.length < count) {
      _distanceControllers.add(TextEditingController());
    }
    while (_distanceControllers.length > count) {
      _distanceControllers.removeLast().dispose();
    }

    while (_holeMapImages.length < count) {
      _holeMapImages.add(null);
    }
    while (_holeMapImages.length > count) {
      _holeMapImages.removeLast();
    }

    while (_teeSignImages.length < count) {
      _teeSignImages.add(null);
    }
    while (_teeSignImages.length > count) {
      _teeSignImages.removeLast();
    }
  }

  Future<void> _pickImageForHole({
    required int holeIndex,
    required bool isHoleMap,
    required ImageSource source,
  }) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 1280,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) return;

      final encoded = _toJpegBase64(bytes);
      if (!mounted) return;
      setState(() {
        if (isHoleMap) {
          _holeMapImages[holeIndex] = encoded;
        } else {
          _teeSignImages[holeIndex] = encoded;
        }
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Unable to pick image from selected source.')),
      );
    }
  }

  Future<void> _showImageSourcePicker(int holeIndex, bool isHoleMap) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Select image source'),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Use Camera'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Photo Library'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;
    await _pickImageForHole(
      holeIndex: holeIndex,
      isHoleMap: isHoleMap,
      source: source,
    );
  }

  void _showImagePreview(String imageData, String title) {
    final isRemote =
        imageData.startsWith('http://') || imageData.startsWith('https://');
    Uint8List? bytes;
    if (!isRemote) {
      try {
        bytes = base64Decode(imageData);
      } catch (_) {
        bytes = null;
      }
    }

    showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900, maxHeight: 700),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: Container(
                    color: Colors.black,
                    width: double.infinity,
                    alignment: Alignment.center,
                    child: bytes == null
                        ? (isRemote
                            ? InteractiveViewer(
                                minScale: 0.5,
                                maxScale: 4.0,
                                child: Image.network(
                                  imageData,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Icon(
                                      Icons.broken_image,
                                      color: Colors.white70,
                                      size: 64),
                                ),
                              )
                            : const Icon(Icons.broken_image,
                                color: Colors.white70, size: 64))
                        : InteractiveViewer(
                            minScale: 0.5,
                            maxScale: 4.0,
                            child: Image.memory(
                              bytes,
                              fit: BoxFit.contain,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageCell({
    required int index,
    required bool isHoleMap,
    double size = 54,
  }) {
    final imageData = isHoleMap ? _holeMapImages[index] : _teeSignImages[index];
    final isRemoteImage = imageData != null &&
        (imageData.startsWith('http://') || imageData.startsWith('https://'));
    return SizedBox(
      width: size + 10,
      child: InkWell(
        onTap: () => _showImageSourcePicker(index, isHoleMap),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(6),
          ),
          child: imageData == null
              ? Icon(Icons.add_a_photo, size: size * 0.36)
              : ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: isRemoteImage
                      ? Image.network(
                          imageData,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.broken_image),
                        )
                      : Builder(
                          builder: (_) {
                            final bytes = _tryDecodeBase64(imageData);
                            if (bytes == null) {
                              return const Icon(Icons.broken_image);
                            }
                            return Image.memory(
                              bytes,
                              fit: BoxFit.cover,
                            );
                          },
                        ),
                ),
        ),
      ),
    );
  }

  Widget _buildSavedImageCell(String? imageData, String title,
      {double size = 54}) {
    if (imageData == null || imageData.isEmpty) {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'No image',
          style: TextStyle(fontSize: size < 45 ? 8 : 10, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      );
    }

    final isRemoteImage =
        imageData.startsWith('http://') || imageData.startsWith('https://');

    try {
      return InkWell(
        onTap: () => _showImagePreview(imageData, title),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: isRemoteImage
              ? Image.network(
                  imageData,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
                )
              : Builder(
                  builder: (_) {
                    final bytes = _tryDecodeBase64(imageData);
                    if (bytes == null) {
                      return const Icon(Icons.broken_image);
                    }
                    return Image.memory(
                      bytes,
                      width: size,
                      height: size,
                      fit: BoxFit.cover,
                    );
                  },
                ),
        ),
      );
    } catch (_) {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(Icons.broken_image, size: 18, color: Colors.grey),
      );
    }
  }

  String _editorHoleFactor(int index) {
    final par = int.tryParse(_parControllers[index].text);
    final distance = int.tryParse(_distanceControllers[index].text);
    if (par == null || par <= 0 || distance == null) {
      return '-';
    }
    return (distance / par).round().toString();
  }

  Widget _buildCompactEditorHoleCard(int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text('${index + 1}', style: const TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 42,
            child: TextFormField(
              controller: _parControllers[index],
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'P',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 68,
            child: TextFormField(
              controller: _distanceControllers[index],
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Dist',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 28,
            child: Text(
              _editorHoleFactor(index),
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(width: 6),
          _buildImageCell(index: index, isHoleMap: true, size: 40),
          const SizedBox(width: 6),
          _buildImageCell(index: index, isHoleMap: false, size: 40),
        ],
      ),
    );
  }

  Widget _buildCompactSavedHoleRow(SavedCourse course, int holeIndex) {
    final par = course.parValues[holeIndex];
    final distance = course.distanceValues[holeIndex];
    final factor = par > 0 ? (distance / par).round().toString() : '-';
    final holeMapImage = holeIndex < course.holeMapImages.length
        ? course.holeMapImages[holeIndex]
        : null;
    final teeSignImage = holeIndex < course.teeSignImages.length
        ? course.teeSignImages[holeIndex]
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(
              width: 22,
              child: Text('${holeIndex + 1}',
                  style: const TextStyle(fontSize: 12))),
          const SizedBox(width: 6),
          SizedBox(
              width: 28,
              child: Text('$par', style: const TextStyle(fontSize: 12))),
          const SizedBox(width: 6),
          SizedBox(
              width: 56,
              child: Text('$distance', style: const TextStyle(fontSize: 12))),
          const SizedBox(width: 6),
          SizedBox(
              width: 28,
              child: Text(factor, style: const TextStyle(fontSize: 12))),
          const SizedBox(width: 6),
          _buildSavedImageCell(
            holeMapImage,
            'Hole Map - ${course.name} - Hole ${holeIndex + 1}',
            size: 40,
          ),
          const SizedBox(width: 6),
          _buildSavedImageCell(
            teeSignImage,
            'Tee Sign - ${course.name} - Hole ${holeIndex + 1}',
            size: 40,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _courseNameController.dispose();
    for (var controller in _parControllers) {
      controller.dispose();
    }
    for (var controller in _distanceControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onNumHolesChanged(int newValue) {
    setState(() {
      numHoles = newValue;
      _ensureControllers(numHoles);
    });
  }

  void _saveCourse() {
    if (_courseNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a course name')),
      );
      return;
    }

    // Validate that all fields are filled
    bool allFilled = true;
    for (int i = 0; i < numHoles; i++) {
      if (_parControllers[i].text.trim().isEmpty ||
          _distanceControllers[i].text.trim().isEmpty) {
        allFilled = false;
        break;
      }
    }

    if (!allFilled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please fill in all par and distance values')),
      );
      return;
    }

    // Collect the par and distance values
    List<int> parValues = [];
    List<int> distanceValues = [];
    for (int i = 0; i < numHoles; i++) {
      parValues.add(int.tryParse(_parControllers[i].text) ?? 3);
      distanceValues.add(int.tryParse(_distanceControllers[i].text) ?? 0);
    }

    // Create the course
    String? existingId;
    if (_editingCourseIndex != null) {
      existingId = widget.savedCourses[_editingCourseIndex!].id;
    }

    final course = SavedCourse(
      id: existingId,
      name: _courseNameController.text.trim(),
      numHoles: numHoles,
      parValues: parValues,
      distanceValues: distanceValues,
      holeMapImages: List<String?>.from(_holeMapImages),
      teeSignImages: List<String?>.from(_teeSignImages),
    );

    final updatedCourses = List<SavedCourse>.from(widget.savedCourses);
    String? oldCourseName;

    if (_editingCourseIndex != null) {
      // Capture old course name before updating
      oldCourseName = widget.savedCourses[_editingCourseIndex!].name;
      final originalCourse = widget.savedCourses[_editingCourseIndex!];

      // Check if Par or Distance values have changed
      bool parOrDistanceChanged = originalCourse.parValues != parValues ||
          originalCourse.distanceValues != distanceValues;

      // Update existing course
      updatedCourses[_editingCourseIndex!] = course;

      // Notify parent about the edit for history versioning
      // Only version games if Par or Distance fields have actually changed
      if (parOrDistanceChanged && widget.onCourseEdited != null) {
        widget.onCourseEdited!(oldCourseName, course.name);
      }
    } else {
      // Add new course
      updatedCourses.add(course);
    }

    widget.onCoursesUpdated(updatedCourses);

    setState(() {
      _editingCourseIndex = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Course "${_courseNameController.text}" saved!')),
    );

    // Clear the form
    _courseNameController.clear();
    for (var controller in _parControllers) {
      controller.text = '3';
    }
    for (var controller in _distanceControllers) {
      controller.clear();
    }
    for (int i = 0; i < _holeMapImages.length; i++) {
      _holeMapImages[i] = null;
    }
    for (int i = 0; i < _teeSignImages.length; i++) {
      _teeSignImages[i] = null;
    }
  }

  void _editCourse(int index) {
    final course = widget.savedCourses[index];

    setState(() {
      _editingCourseIndex = index;
      _courseNameController.text = course.name;
      numHoles = course.numHoles;
      _ensureControllers(numHoles);

      for (int i = 0; i < course.numHoles; i++) {
        _parControllers[i].text = course.parValues[i].toString();
        _distanceControllers[i].text = course.distanceValues[i].toString();
        _holeMapImages[i] =
            i < course.holeMapImages.length ? course.holeMapImages[i] : null;
        _teeSignImages[i] =
            i < course.teeSignImages.length ? course.teeSignImages[i] : null;
      }
    });

    // Scroll to top to see the form
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Editing "${course.name}"')),
    );
  }

  void _cancelEdit() {
    setState(() {
      _editingCourseIndex = null;
      _courseNameController.clear();
      for (var controller in _parControllers) {
        controller.text = '3';
      }
      for (var controller in _distanceControllers) {
        controller.clear();
      }
      for (int i = 0; i < _holeMapImages.length; i++) {
        _holeMapImages[i] = null;
      }
      for (int i = 0; i < _teeSignImages.length; i++) {
        _teeSignImages[i] = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isCompactLayout =
        MediaQuery.of(context).size.width < _compactLayoutBreakpoint;
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(isCompactLayout ? 12.0 : 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _editingCourseIndex != null
                        ? 'Edit Course'
                        : 'Add New Course',
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  if (_editingCourseIndex != null)
                    TextButton.icon(
                      onPressed: _cancelEdit,
                      icon: const Icon(Icons.cancel),
                      label: const Text('Cancel Edit'),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              // Course Name
              SizedBox(
                width: 300,
                child: TextFormField(
                  controller: _courseNameController,
                  maxLength: 30,
                  inputFormatters: [LengthLimitingTextInputFormatter(30)],
                  decoration: const InputDecoration(
                    labelText: 'Course Name',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Number of Holes Dropdown
              Row(
                children: [
                  const Text('Number of Holes: ',
                      style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 10),
                  DropdownButton<int>(
                    value: numHoles,
                    items: [9, 18].map((int value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text(value.toString()),
                      );
                    }).toList(),
                    onChanged: (int? newValue) {
                      if (newValue == null) return;
                      _onNumHolesChanged(newValue);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (isCompactLayout)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        SizedBox(
                            width: 22,
                            child: Text('H',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold))),
                        SizedBox(width: 6),
                        SizedBox(
                            width: 42,
                            child: Text('Par',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold))),
                        SizedBox(width: 6),
                        SizedBox(
                            width: 68,
                            child: Text('Dist',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold))),
                        SizedBox(width: 6),
                        SizedBox(
                            width: 28,
                            child: Text('F',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold))),
                        SizedBox(width: 6),
                        SizedBox(
                            width: 50,
                            child: Text('Map',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold))),
                        SizedBox(width: 6),
                        SizedBox(
                            width: 50,
                            child: Text('Tee',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...List.generate(
                      numHoles,
                      (index) => _buildCompactEditorHoleCard(index),
                    ),
                  ],
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row
                      const Row(
                        children: [
                          SizedBox(
                              width: 60,
                              child: Text('Hole',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          SizedBox(
                              width: 100,
                              child: Text('Par',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          SizedBox(
                              width: 100,
                              child: Text('Distance (ft)',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          SizedBox(
                              width: 100,
                              child: Text('Factor',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          SizedBox(
                              width: 120,
                              child: Text('Hole Map',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          SizedBox(
                              width: 120,
                              child: Text('Tee Sign',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Hole entries
                      ...List.generate(numHoles, (index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 60,
                                child: Text('${index + 1}',
                                    style: const TextStyle(fontSize: 16)),
                              ),
                              SizedBox(
                                width: 90,
                                child: TextFormField(
                                  controller: _parControllers[index],
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly
                                  ],
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 8),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 90,
                                child: TextFormField(
                                  controller: _distanceControllers[index],
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly
                                  ],
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 8),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 90,
                                child: Builder(
                                  builder: (context) {
                                    final par = int.tryParse(
                                        _parControllers[index].text);
                                    final distance = int.tryParse(
                                        _distanceControllers[index].text);
                                    final factor = (par != null &&
                                            par > 0 &&
                                            distance != null)
                                        ? (distance / par).round().toString()
                                        : '-';
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 12),
                                      alignment: Alignment.centerLeft,
                                      child: Text(factor,
                                          style: const TextStyle(fontSize: 16)),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              _buildImageCell(index: index, isHoleMap: true),
                              const SizedBox(width: 10),
                              _buildImageCell(index: index, isHoleMap: false),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              const SizedBox(height: 30),
              // Save Button
              ElevatedButton.icon(
                onPressed: _saveCourse,
                icon: const Icon(Icons.save),
                label: Text(_editingCourseIndex != null
                    ? 'Update Course'
                    : 'Save Course'),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              const SizedBox(height: 40),
              // Saved Courses Section
              if (widget.savedCourses.isNotEmpty) ...[
                const Divider(thickness: 2),
                const SizedBox(height: 20),
                const Text(
                  'Saved Courses',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                // Display each saved course (sorted alphabetically)
                ...() {
                  final sortedCourses = List<SavedCourse>.from(
                      widget.savedCourses)
                    ..sort((a, b) =>
                        a.name.toLowerCase().compareTo(b.name.toLowerCase()));
                  return List.generate(sortedCourses.length, (courseIndex) {
                    final course = sortedCourses[courseIndex];
                    final originalIndex = widget.savedCourses.indexOf(course);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 20),
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Course Header with Edit button
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        course.name,
                                        style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        '${course.numHoles} holes',
                                        style: const TextStyle(
                                            fontSize: 16, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit,
                                      color: Colors.orange),
                                  onPressed: () => _editCourse(originalIndex),
                                  tooltip: 'Edit Course',
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Course details table
                            if (isCompactLayout)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      SizedBox(
                                          width: 22,
                                          child: Text('H',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight:
                                                      FontWeight.bold))),
                                      SizedBox(width: 6),
                                      SizedBox(
                                          width: 28,
                                          child: Text('Par',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight:
                                                      FontWeight.bold))),
                                      SizedBox(width: 6),
                                      SizedBox(
                                          width: 56,
                                          child: Text('Dist',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight:
                                                      FontWeight.bold))),
                                      SizedBox(width: 6),
                                      SizedBox(
                                          width: 28,
                                          child: Text('F',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight:
                                                      FontWeight.bold))),
                                      SizedBox(width: 6),
                                      SizedBox(
                                          width: 40,
                                          child: Text('Map',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight:
                                                      FontWeight.bold))),
                                      SizedBox(width: 6),
                                      SizedBox(
                                          width: 40,
                                          child: Text('Tee',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight:
                                                      FontWeight.bold))),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ...List.generate(
                                    course.numHoles,
                                    (holeIndex) => _buildCompactSavedHoleRow(
                                        course, holeIndex),
                                  ),
                                ],
                              )
                            else
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const SizedBox(
                                            width: 60,
                                            child: Text('Hole',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold))),
                                        const SizedBox(
                                            width: 60,
                                            child: Text('Par',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold))),
                                        const SizedBox(
                                            width: 100,
                                            child: Text('Distance',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold))),
                                        const SizedBox(
                                            width: 100,
                                            child: Text('Factor',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold))),
                                        const SizedBox(
                                            width: 110,
                                            child: Text('Hole Map',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold))),
                                        const SizedBox(
                                            width: 110,
                                            child: Text('Tee Sign',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold))),
                                      ],
                                    ),
                                    const Divider(),
                                    // Display each hole
                                    ...List.generate(course.numHoles,
                                        (holeIndex) {
                                      final par = course.parValues[holeIndex];
                                      final distance =
                                          course.distanceValues[holeIndex];
                                      final factor = par > 0
                                          ? (distance / par).round().toString()
                                          : '-';
                                      final holeMapImage = holeIndex <
                                              course.holeMapImages.length
                                          ? course.holeMapImages[holeIndex]
                                          : null;
                                      final teeSignImage = holeIndex <
                                              course.teeSignImages.length
                                          ? course.teeSignImages[holeIndex]
                                          : null;
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 4.0),
                                        child: Row(
                                          children: [
                                            SizedBox(
                                                width: 60,
                                                child:
                                                    Text('${holeIndex + 1}')),
                                            SizedBox(
                                                width: 60, child: Text('$par')),
                                            SizedBox(
                                                width: 100,
                                                child: Text('$distance ft')),
                                            SizedBox(
                                                width: 100,
                                                child: Text(factor)),
                                            SizedBox(
                                              width: 110,
                                              child: _buildSavedImageCell(
                                                holeMapImage,
                                                'Hole Map - ${course.name} - Hole ${holeIndex + 1}',
                                              ),
                                            ),
                                            SizedBox(
                                              width: 110,
                                              child: _buildSavedImageCell(
                                                teeSignImage,
                                                'Tee Sign - ${course.name} - Hole ${holeIndex + 1}',
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 8),
                            // Total par and distance
                            Row(
                              children: [
                                const SizedBox(
                                    width: 60,
                                    child: Text('Total',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold))),
                                SizedBox(
                                  width: 60,
                                  child: Text(
                                    '${course.parValues.reduce((a, b) => a + b)}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                SizedBox(
                                  width: 100,
                                  child: Text(
                                    '${course.distanceValues.reduce((a, b) => a + b)} ft',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  });
                }(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
