import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:animate_do/animate_do.dart';
import 'package:uuid/uuid.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Alumni App',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple),
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        title: Row(
          children: [
            Image.asset('assets/MBU.png', width: 80, height: 80),
            const SizedBox(width: 8),
            const Text('Mohan Babu University'),
          ],
        ),
      ),
      body: const MemberListScreen(),
      bottomNavigationBar: const MyBottomNavigationBar(selectedIndex: 0),
    );
  }
}

class UpdatesScreen extends StatefulWidget {
  const UpdatesScreen({super.key});

  @override
  State<UpdatesScreen> createState() => _UpdatesScreenState();
}

class _UpdatesScreenState extends State<UpdatesScreen> {
  Map<String, List<UpdateItem>> _allUpdates = {};
  Timer? _expirationTimer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUpdates();
    _startExpirationCheck();
  }

  @override
  void dispose() {
    _expirationTimer?.cancel();
    super.dispose();
  }

  void _startExpirationCheck() {
    _expirationTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkExpiredPosts();
    });
  }

  Future<void> _checkExpiredPosts() async {
    bool needsUpdate = false;
    final now = DateTime.now();

    setState(() {
      for (var memberUpdates in _allUpdates.values) {
        for (var update in memberUpdates) {
          if (update.expirationDate != null &&
              now.isAfter(update.expirationDate!)) {
            update.isExpired = true;
            needsUpdate = true;
          }
        }
      }
    });

    if (needsUpdate) {
      await _saveUpdates();
    }
  }

  Future<void> _loadUpdates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('updates') ?? '{}';

      final Map<String, dynamic> decodedData = jsonDecode(jsonString);
      final Map<String, List<UpdateItem>> loadedUpdates = {};

      decodedData.forEach((key, value) {
        try {
          final List<dynamic> updateList = value as List<dynamic>;
          loadedUpdates[key] =
              updateList.map((item) => UpdateItem.fromJson(item)).toList();
        } catch (e, stacktrace) {
          print('Error loading updates for key $key: $e\n$stacktrace');
        }
      });

      if (mounted) {
        setState(() {
          _allUpdates = loadedUpdates;
          _checkExpiredPosts();
          _isLoading = false;
        });
      }
    } catch (e, stacktrace) {
      print('Error loading updates: $e\n$stacktrace');
      if (mounted) {
        setState(() {
          _allUpdates = {};
          _isLoading = false;
        });
      }
    }
  }

  List<UpdateItem> get _allValidUpdates {
    List<UpdateItem> allUpdates = [];
    _allUpdates.forEach((key, value) {
      allUpdates.addAll(value.where((update) => !update.isExpired));
    });
    allUpdates.sort(
      (a, b) => DateTime.parse(b.time).compareTo(DateTime.parse(a.time)),
    );
    return allUpdates;
  }

  Future<void> _saveUpdates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> jsonData = {};

      _allUpdates.forEach((key, value) {
        jsonData[key] = value.map((item) => item.toJson()).toList();
      });

      final String jsonString = jsonEncode(jsonData);
      await prefs.setString('updates', jsonString);
    } catch (e, stacktrace) {
      print('Error saving updates: $e\n$stacktrace');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        title: const Text('Updates'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showNewUpdateDialog(context),
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _allValidUpdates.isEmpty
              ? const Center(
                child: Text(
                  'No updates yet',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              )
              : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _allValidUpdates.length,
                separatorBuilder:
                    (context, index) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final update = _allValidUpdates[index];
                  String memberId = _allUpdates.keys.firstWhere(
                    (key) => _allUpdates[key]!.contains(update),
                  );
                  return _buildUpdateCard(update, memberId, index);
                },
              ),
      bottomNavigationBar: const MyBottomNavigationBar(selectedIndex: 1),
    );
  }

  Widget _buildUpdateCard(UpdateItem update, String memberId, int index) {
    final posterName = update.posterName ?? 'Unknown';
    final truncatedPosterName =
        posterName.length > 20
            ? '${posterName.substring(0, 20)}...'
            : posterName;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(update.icon, color: Colors.blue, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        update.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Posted by: $truncatedPosterName',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatTimestamp(update.time),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    if (update.expirationDate != null)
                      Text(
                        'Expires: ${DateFormat('MMM d').format(update.expirationDate!)}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (update.imageUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.file(
                    File(update.imageUrl!),
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (update.videoUrl != null) ...[
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.black,
                ),
                constraints: const BoxConstraints(maxHeight: 300),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: VideoDisplay(videoUrl: update.videoUrl!),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (update.description.isNotEmpty) ...[
              Text(
                update.description,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
              ),
              const SizedBox(height: 16),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildInteractionButton(
                  icon:
                      update.isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                  label: 'Like',
                  isActive: update.isLiked,
                  onTap: () => _toggleLike(memberId, index),
                ),
                _buildInteractionButton(
                  icon:
                      update.isDisliked
                          ? Icons.thumb_down
                          : Icons.thumb_down_outlined,
                  label: 'Dislike',
                  isActive: update.isDisliked,
                  onTap: () => _toggleDislike(memberId, index),
                ),
                _buildInteractionButton(
                  icon: Icons.comment_outlined,
                  label: 'Comment',
                  onTap:
                      () => _toggleCommentSection(
                        context,
                        update,
                        memberId,
                        index,
                      ),
                ),
                _buildInteractionButton(
                  icon: Icons.report_outlined,
                  label: 'Report',
                  onTap: () => _reportPost(context, memberId, index),
                ),
              ],
            ),
            if (update.showComments)
              _buildCommentSection(context, update, memberId, index),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) return 'Just now';
      if (difference.inHours < 1) return '${difference.inMinutes}m ago';
      if (difference.inDays < 1) return '${difference.inHours}h ago';
      if (difference.inDays < 7) return '${difference.inDays}d ago';

      return DateFormat('MMM d, yyyy').format(dateTime);
    } catch (e) {
      return 'Some time ago';
    }
  }

  Widget _buildInteractionButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    bool isActive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color:
                  isActive
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey.shade600,
              size: 20,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color:
                    isActive
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleLike(String memberId, int index) {
    setState(() {
      final update = _allUpdates[memberId]![index];
      update.isLiked = !update.isLiked;
      if (update.isLiked) update.isDisliked = false;
      _saveUpdates();
    });
  }

  void _toggleDislike(String memberId, int index) {
    setState(() {
      final update = _allUpdates[memberId]![index];
      update.isDisliked = !update.isDisliked;
      if (update.isDisliked) update.isLiked = false;
      _saveUpdates();
    });
  }

  void _reportPost(BuildContext context, String memberId, int index) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Report Post'),
          content: const Text('This post will be reviewed by our team.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Post reported')));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400,
              ),
              child: const Text(
                'Report',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _toggleCommentSection(
    BuildContext context,
    UpdateItem update,
    String memberId,
    int index,
  ) {
    setState(() {
      update.showComments = !update.showComments;
    });
  }

  Widget _buildCommentSection(
    BuildContext context,
    UpdateItem update,
    String memberId,
    int index,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          'Comments',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        if (update.comments != null && update.comments!.isNotEmpty)
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: update.comments!.length,
            itemBuilder: (context, commentIndex) {
              final comment = update.comments![commentIndex];
              return _buildCommentTile(comment);
            },
          )
        else
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text('No comments yet.'),
          ),
        _buildCommentInputField(context, update, memberId, index),
      ],
    );
  }

  Widget _buildCommentTile(Comment comment) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            comment.author,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(comment.text),
        ],
      ),
    );
  }

  Widget _buildCommentInputField(
    BuildContext context,
    UpdateItem update,
    String memberId,
    int index,
  ) {
    final commentController = TextEditingController();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: commentController,
              decoration: const InputDecoration(
                hintText: 'Add a comment...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: () {
              final newComment = Comment(
                author: 'You',
                text: commentController.text,
              );
              setState(() {
                update.comments ??= [];
                update.comments!.add(newComment);
                commentController.clear();
                _saveUpdates();
              });
            },
          ),
        ],
      ),
    );
  }

  void _showNewUpdateDialog(BuildContext context) async {
    final result = await showDialog<UpdateItem>(
      context: context,
      builder: (context) => const NewUpdateDialog(),
    );

    if (result != null) {
      final prefs = await SharedPreferences.getInstance();
      final currentUserId = prefs.getString('currentUserId') ?? 'defaultUser';

      setState(() {
        _allUpdates.putIfAbsent(currentUserId, () => []).add(result);
        _saveUpdates();
      });
    }
  }
}

class NewUpdateDialog extends StatefulWidget {
  const NewUpdateDialog({super.key});

  @override
  _NewUpdateDialogState createState() => _NewUpdateDialogState();
}

class _NewUpdateDialogState extends State<NewUpdateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  File? _image;
  String? _video;
  int _expirationDays = 7;
  String? _posterName = "Alumni";

  Future<File?> _compressVideo(String videoPath) async {
    final tempDir = await getTemporaryDirectory();
    final compressedVideoPath = '${tempDir.path}/compressed_video.mp4';

    final originalFile = File(videoPath);
    try {
      await originalFile.copy(compressedVideoPath);
      return File(compressedVideoPath);
    } catch (e) {
      print('Error during "compression": $e');
      return null;
    }
  }

  Future<void> _pickMedia(bool isImage) async {
    final picker = ImagePicker();
    final XFile? pickedFile =
        isImage
            ? await picker.pickImage(source: ImageSource.gallery)
            : await picker.pickVideo(source: ImageSource.gallery);

    if (pickedFile != null) {
      if (isImage) {
        setState(() {
          _image = File(pickedFile.path);
          _video = null;
        });
      } else {
        File? compressedVideoFile = await _compressVideo(pickedFile.path);
        if (compressedVideoFile != null) {
          setState(() {
            _video = compressedVideoFile.path;
            _image = null;
          });
        } else {
          print("Video compression failed!");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Video compression failed. Please try a different video.",
              ),
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Create New Update',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator:
                      (value) =>
                          value?.isEmpty ?? true
                              ? 'Please enter a title'
                              : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator:
                      (value) =>
                          value?.isEmpty ?? true
                              ? 'Please enter a description'
                              : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Your Name',
                    hintText: 'Enter your name',
                  ),
                  onChanged: (value) {
                    setState(() {
                      _posterName = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                if (_image != null || _video != null) ...[
                  Row(
                    children: [
                      const Text('Expires in: '),
                      DropdownButton<int>(
                        value: _expirationDays,
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('1 day')),
                          DropdownMenuItem(value: 3, child: Text('3 days')),
                          DropdownMenuItem(value: 7, child: Text('7 days')),
                          DropdownMenuItem(value: 14, child: Text('14 days')),
                          DropdownMenuItem(value: 30, child: Text('30 days')),
                          DropdownMenuItem(value: -1, child: Text('Never')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _expirationDays = value!;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.image, size: 20),
                        label: const Text('Add Image'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () => _pickMedia(true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.videocam, size: 20),
                        label: const Text('Add Video'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () => _pickMedia(false),
                      ),
                    ),
                  ],
                ),
                if (_image != null || _video != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child:
                        _image != null
                            ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(_image!, fit: BoxFit.cover),
                            )
                            : Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.videocam,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Video selected',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (_formKey.currentState?.validate() ?? false) {
                            final now = DateTime.now();
                            final expirationDate =
                                _expirationDays > 0
                                    ? now.add(Duration(days: _expirationDays))
                                    : null;

                            final newUpdate = UpdateItem(
                              title: _titleController.text,
                              description: _descriptionController.text,
                              time: now.toIso8601String(),
                              icon:
                                  _image != null
                                      ? Icons.image
                                      : _video != null
                                      ? Icons.videocam
                                      : Icons.article,
                              imageUrl: _image?.path,
                              videoUrl: _video,
                              posterName: _posterName,
                              status: MessageStatus.sent,
                              expirationDate: expirationDate,
                            );
                            Navigator.pop(context, newUpdate);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Post'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class UpdateItem {
  final String title;
  final String description;
  final String time;
  final IconData icon;
  final String? imageUrl;
  final String? videoUrl;
  String? posterName;
  bool isLiked;
  bool isDisliked;
  bool isExpired;
  MessageStatus? status;
  final DateTime? expirationDate;
  List<Comment>? comments;
  bool showComments;

  UpdateItem({
    required this.title,
    required this.description,
    required this.time,
    required this.icon,
    this.imageUrl,
    this.videoUrl,
    this.posterName,
    this.isLiked = false,
    this.isDisliked = false,
    this.isExpired = false,
    this.status,
    this.expirationDate,
    this.comments,
    this.showComments = false,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'time': time,
    'icon': icon.codePoint,
    'imageUrl': imageUrl,
    'videoUrl': videoUrl,
    'posterName': posterName,
    'isLiked': isLiked,
    'isDisliked': isDisliked,
    'isExpired': isExpired,
    'status': status?.index,
    'expirationDate': expirationDate?.toIso8601String(),
    'comments': comments?.map((comment) => comment.toJson()).toList(),
    'showComments': showComments,
  };

  factory UpdateItem.fromJson(Map<String, dynamic> json) => UpdateItem(
    title: json['title'],
    description: json['description'],
    time: json['time'],
    icon: IconData(json['icon'], fontFamily: 'MaterialIcons'),
    imageUrl: json['imageUrl'],
    videoUrl: json['videoUrl'],
    posterName: json['posterName'],
    isLiked: json['isLiked'] ?? false,
    isDisliked: json['isDisliked'] ?? false,
    isExpired: json['isExpired'] ?? false,
    status:
        json['status'] != null ? MessageStatus.values[json['status']] : null,
    expirationDate:
        json['expirationDate'] != null
            ? DateTime.parse(json['expirationDate'])
            : null,
    comments:
        (json['comments'] as List<dynamic>?)
            ?.map((commentJson) => Comment.fromJson(commentJson))
            .toList(),
    showComments: json['showComments'] ?? false,
  );
}

enum MessageStatus { sent, delivered, read }

class VideoDisplay extends StatefulWidget {
  final String videoUrl;

  const VideoDisplay({super.key, required this.videoUrl});

  @override
  _VideoDisplayState createState() => _VideoDisplayState();
}

class _VideoDisplayState extends State<VideoDisplay> {
  late VideoPlayerController _controller;
  bool _showControls = false;
  bool _isPlaying = false;
  bool _isInitialized = false;
  bool _isMuted = false;
  bool _isFullScreen = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.file(File(widget.videoUrl));
      await _controller.initialize();
      _controller.setLooping(true);
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load video';
        _isInitialized = false;
      });
      print('Error initializing video: $e');
    }
  }

  void _togglePlayPause() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
        _isPlaying = false;
      } else {
        _controller.play();
        _isPlaying = true;
      }
    });
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _controller.setVolume(_isMuted ? 0 : 1);
    });
  }

  void _toggleFullScreen() {
    if (_isFullScreen) {
      Navigator.of(context).pop();
      setState(() {
        _isFullScreen = false;
      });
    } else {
      Navigator.of(context).push(
        PageRouteBuilder(
          opaque: false,
          pageBuilder:
              (_, __, ___) => FullScreenVideo(
                controller: _controller,
                isPlaying: _isPlaying,
                isMuted: _isMuted,
                onClose: () {
                  Navigator.of(context).pop();
                  setState(() {
                    _isFullScreen = false;
                  });
                },
                togglePlayPause: _togglePlayPause,
                toggleMute: _toggleMute,
              ),
        ),
      );
      setState(() {
        _isFullScreen = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Center(
        child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
      );
    }

    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _showControls = !_showControls;
          });
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(_controller),
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                color: Colors.black54,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(
                        _isPlaying ? Icons.pause : Icons.play_arrow,
                        size: 50,
                        color: Colors.white,
                      ),
                      onPressed: _togglePlayPause,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: Icon(
                            _isMuted ? Icons.volume_off : Icons.volume_up,
                            color: Colors.white,
                          ),
                          onPressed: _toggleMute,
                        ),
                        const SizedBox(width: 20),
                        IconButton(
                          icon: const Icon(
                            Icons.fullscreen,
                            color: Colors.white,
                          ),
                          onPressed: _toggleFullScreen,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (!_showControls && !_isPlaying)
              IconButton(
                icon: const Icon(
                  Icons.play_arrow,
                  size: 50,
                  color: Colors.white70,
                ),
                onPressed: _togglePlayPause,
              ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: VideoProgressIndicator(
                _controller,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: Colors.red,
                  bufferedColor: Colors.grey,
                  backgroundColor: Colors.white24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FullScreenVideo extends StatelessWidget {
  final VideoPlayerController controller;
  final bool isPlaying;
  final bool isMuted;
  final VoidCallback onClose;
  final VoidCallback togglePlayPause;
  final VoidCallback toggleMute;

  const FullScreenVideo({
    super.key,
    required this.controller,
    required this.isPlaying,
    required this.isMuted,
    required this.onClose,
    required this.togglePlayPause,
    required this.toggleMute,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
          ),
          Positioned(
            top: 40,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
              onPressed: onClose,
            ),
          ),
          Center(
            child: IconButton(
              icon: Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 50,
              ),
              onPressed: togglePlayPause,
            ),
          ),
          Positioned(
            bottom: 40,
            right: 20,
            child: IconButton(
              icon: Icon(
                isMuted ? Icons.volume_off : Icons.volume_up,
                color: Colors.white,
                size: 30,
              ),
              onPressed: toggleMute,
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: VideoProgressIndicator(
              controller,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: Colors.red,
                bufferedColor: Colors.grey,
                backgroundColor: Colors.white24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final Map<String, List<ChatMessage>> _conversations = {};
  final Map<String, Member> _contacts = {};
  bool _isLoading = true;
  String _currentUserId = 'defaultUser';

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
  }

  Future<void> _loadCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('currentUserId');
    if (userId == null) {
      userId = const Uuid().v4();
      await prefs.setString('currentUserId', userId);
    }
    setState(() {
      _currentUserId = userId!;
      _loadConversations();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadConversations() async {
    print('Loading conversations for user: $_currentUserId');
    final prefs = await SharedPreferences.getInstance();

    try {
      final contactsJsonString = prefs.getString('contacts') ?? '{}';
      final conversationsJsonString = prefs.getString('conversations') ?? '{}';

      print('Raw contacts JSON: $contactsJsonString');
      print('Raw conversations JSON: $conversationsJsonString');

      final Map<String, dynamic> contactsJson = jsonDecode(contactsJsonString);
      final Map<String, dynamic> conversationsJson = jsonDecode(
        conversationsJsonString,
      );

      contactsJson.forEach((memberId, memberData) {
        try {
          _contacts[memberId] = Member.fromJson(
            memberData as Map<String, dynamic>,
          );
        } catch (e, stacktrace) {
          print(
            'Error parsing member data for memberId $memberId: $e\n$stacktrace',
          );
          _contacts[memberId] = Member(
            id: memberId,
            name: 'Unknown Member',
            description: 'Could not load',
            imageUrl: 'https://via.placeholder.com/150',
            company: 'N/A',
            location: 'N/A',
            alumniYear: null,
            role: null,
          );
        }
      });

      conversationsJson.forEach((chatKey, messages) {
        try {
          _conversations[chatKey] =
              (messages as List<dynamic>)
                  .map(
                    (msg) => ChatMessage.fromJson(msg as Map<String, dynamic>),
                  )
                  .toList();
        } catch (e, stacktrace) {
          print(
            'Error parsing chat message for chatKey $chatKey: $e\n$stacktrace',
          );
        }
      });

      _conversations.forEach((chatKey, value) {
        final memberId = chatKey.replaceAll(
          'chatHistory_${_currentUserId}_',
          '',
        );
        if (!_contacts.containsKey(memberId)) {
          print('Contact not found for $memberId, chatKey: $chatKey');
        }
      });
    } catch (e, stacktrace) {
      print('Error loading conversations: $e\n$stacktrace');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveConversations() async {
    print('Saving conversations...');
    final prefs = await SharedPreferences.getInstance();

    try {
      final contactsJson = _contacts.map(
        (key, value) => MapEntry(key, value.toJson()),
      );
      final conversationsJson = _conversations.map(
        (key, value) => MapEntry(key, value.map((e) => e.toJson()).toList()),
      );

      final String contactsJsonString = jsonEncode(contactsJson);
      final String conversationsJsonString = jsonEncode(conversationsJson);

      print('Saving contacts JSON: $contactsJsonString');
      print('Saving conversations JSON: $conversationsJsonString');

      await prefs.setString('contacts', contactsJsonString);
      await prefs.setString('conversations', conversationsJsonString);
    } catch (e, stacktrace) {
      print('Error saving conversations: $e\n$stacktrace');
    }
  }

  void _addMessage(String chatKey, ChatMessage message) {
    setState(() {
      _conversations.putIfAbsent(chatKey, () => []).add(message);
      _saveConversations();
    });
  }

  String _getChatKey(String memberId, String currentUserId) {
    return 'chatHistory_${currentUserId}_$memberId';
  }

  List<MapEntry<String, List<ChatMessage>>> get _sortedConversations {
    final sorted = _conversations.entries.toList();
    sorted.sort((a, b) {
      final lastMsgA = a.value.lastOrNull?.time ?? '';
      final lastMsgB = b.value.lastOrNull?.time ?? '';
      if (lastMsgA.isEmpty && lastMsgB.isEmpty) {
        return 0;
      } else if (lastMsgA.isEmpty) {
        return 1;
      } else if (lastMsgB.isEmpty) {
        return -1;
      }
      return lastMsgB.compareTo(lastMsgA);
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    print('Building MessagesScreen');
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        title: const Text('Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearchDialog(context),
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _conversations.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.forum_outlined,
                      size: 80,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No messages yet',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Start a conversation by connecting with alumni',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              )
              : ListView.builder(
                padding: const EdgeInsets.only(top: 8),
                itemCount: _sortedConversations.length,
                itemBuilder: (context, index) {
                  final entry = _sortedConversations[index];
                  final chatKey = entry.key;
                  final messages = entry.value;
                  final memberId = chatKey.replaceAll(
                    'chatHistory_${_currentUserId}_',
                    '',
                  );

                  final member = _contacts[memberId];
                  final lastMessage = messages.lastOrNull;

                  if (member == null || lastMessage == null) {
                    print(
                      'Warning: Member or lastMessage is null for chatKey: $chatKey',
                    );
                    return const SizedBox.shrink();
                  }

                  return FadeInUp(
                    delay: Duration(milliseconds: 100 * index),
                    child: _buildConversationCard(
                      context,
                      member,
                      lastMessage,
                      messages.length,
                      chatKey,
                    ),
                  );
                },
              ),
      bottomNavigationBar: const MyBottomNavigationBar(selectedIndex: 2),
    );
  }

  Widget _buildConversationCard(
    BuildContext context,
    Member member,
    ChatMessage lastMessage,
    int messageCount,
    String chatKey,
  ) {
    final unreadCount = messageCount;
    final time = _formatTimestamp(lastMessage.time);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => ChatScreen(
                    currentUserId: _currentUserId,
                    member: member,
                    onMessageSent: (message) {
                      _addMessage(chatKey, message);
                    },
                    onUpdateContacts: (Member updatedMember) {
                      setState(() {
                        _contacts[member.id] = updatedMember;
                      });
                      _saveConversations();
                    },
                    chatKey: chatKey,
                  ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Hero(
                tag: 'member_avatar_${member.id}',
                child: CircleAvatar(
                  radius: 24,
                  backgroundImage: CachedNetworkImageProvider(member.imageUrl),
                  onBackgroundImageError: (exception, stackTrace) {
                    print('Image load error: $exception');
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          member.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          time,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lastMessage.text.isNotEmpty
                          ? lastMessage.text
                          : 'Media message',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (unreadCount > 0)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    unreadCount.toString(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) return 'Just now';
      if (difference.inHours < 1) return '${difference.inMinutes}m ago';
      if (difference.inDays < 1) return DateFormat('h:mm a').format(dateTime);
      if (difference.inDays < 7) return DateFormat('EEE').format(dateTime);

      return DateFormat('MMM d').format(dateTime);
    } catch (e) {
      return '';
    }
  }

  void _showSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Search Messages'),
          content: const Text('Search functionality will be implemented here'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        title: const Text('Notifications'),
      ),
      body: ListView(
        children: const [
          NotificationCard(
            content: 'Shaik Mohammad Muddassir sent you a message.',
            time: '5 minutes ago',
            backgroundColor: Color.fromARGB(255, 223, 245, 240),
          ),
          NotificationCard(
            content: 'Chenji Nithin Kumar liked your profile.',
            time: '1 hour ago',
            backgroundColor: Color.fromARGB(255, 185, 221, 241),
          ),
          NotificationCard(
            content: 'Arigala Punith Kumar accepted your connection request.',
            time: 'Yesterday',
            backgroundColor: Color.fromARGB(255, 244, 211, 170),
          ),
        ],
      ),
      bottomNavigationBar: const MyBottomNavigationBar(selectedIndex: 3),
    );
  }
}

class NotificationCard extends StatelessWidget {
  final String content;
  final String time;
  final Color backgroundColor;

  const NotificationCard({
    super.key,
    required this.content,
    required this.time,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(content, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text(time, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class MyBottomNavigationBar extends StatefulWidget {
  const MyBottomNavigationBar({super.key, this.selectedIndex = 0});
  final int selectedIndex;

  @override
  State<MyBottomNavigationBar> createState() => _MyBottomNavigationBarState();
}

class _MyBottomNavigationBarState extends State<MyBottomNavigationBar> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.selectedIndex;
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const UpdatesScreen()),
        );
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MessagesScreen()),
        );
        break;
      case 3:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const NotificationsScreen()),
        );
        break;
      case 4:
        _showMoreOptions(context);
        break;
    }
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.help),
              title: const Text('Help & Support'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      items: const <BottomNavigationBarItem>[
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.update), label: 'Updates'),
        BottomNavigationBarItem(icon: Icon(Icons.message), label: 'Messages'),
        BottomNavigationBarItem(
          icon: Icon(Icons.notifications),
          label: 'Notifications',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'More'),
      ],
      currentIndex: _selectedIndex,
      selectedItemColor: Theme.of(context).colorScheme.primary,
      unselectedItemColor: Colors.grey,
      onTap: _onItemTapped,
      type: BottomNavigationBarType.fixed,
    );
  }
}

class Comment {
  final String author;
  final String text;

  Comment({required this.author, required this.text});

  Map<String, dynamic> toJson() => {'author': author, 'text': text};

  factory Comment.fromJson(Map<String, dynamic> json) =>
      Comment(author: json['author'], text: json['text']);
}

class MemberCard extends StatelessWidget {
  const MemberCard({
    super.key,
    required this.member,
    required this.currentUserId,
  });

  final Member member;
  final String currentUserId;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: NetworkImage(member.imageUrl),
                  radius: 30,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text('Company: ${member.company}'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Location: ${member.location}'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => ChatScreen(
                          currentUserId: currentUserId,
                          member: member,
                          onMessageSent: (message) {},
                          onUpdateContacts: (Member updatedMember) {},
                          chatKey: '',
                        ),
                  ),
                );
              },
              icon: const Icon(Icons.connect_without_contact),
              label: const Text('Connect'),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String currentUserId;
  final Member member;
  final String chatKey;
  final Function(ChatMessage) onMessageSent;
  final Function(Member) onUpdateContacts;

  const ChatScreen({
    super.key,
    required this.currentUserId,
    required this.member,
    required this.chatKey,
    required this.onMessageSent,
    required this.onUpdateContacts,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  List<ChatMessage> _messages = [];
  bool _isEditing = false;
  late Member _member;
  late String _chatKey;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _member = Member.fromJson(widget.member.toJson());
    _chatKey =
        widget.chatKey.isNotEmpty
            ? widget.chatKey
            : _generateChatKey(_member.id);
    _loadMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  String _generateChatKey(String memberId) {
    return 'chatHistory_${widget.currentUserId}_$memberId';
  }

  Future<void> _loadMessages() async {
    print('Loading messages with chatKey: $_chatKey');
    final prefs = await SharedPreferences.getInstance();

    try {
      final chatHistory = prefs.getStringList(_chatKey);

      if (chatHistory != null) {
        List<ChatMessage> loadedMessages = [];
        for (String item in chatHistory) {
          try {
            final json = jsonDecode(item);
            final message = ChatMessage.fromJson(json);
            loadedMessages.add(message);
          } catch (e, stacktrace) {
            print('Error decoding message: $e, raw data: $item\n$stacktrace');
          }
        }

        if (mounted) {
          setState(() {
            _messages = loadedMessages.reversed.toList();
            _isLoading = false;
          });
        }
      } else {
        print('No chat history found for key: $_chatKey');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e, stacktrace) {
      print('Error loading messages: $e\n$stacktrace');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveMessages() async {
    print('Saving messages with chatKey: $_chatKey');
    final prefs = await SharedPreferences.getInstance();
    try {
      final chatHistory =
          _messages.map((message) => jsonEncode(message.toJson())).toList();
      await prefs.setStringList(_chatKey, chatHistory.reversed.toList());
    } catch (e, stacktrace) {
      print('Error saving messages: $e\n$stacktrace');
    }
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isNotEmpty) {
      final message = ChatMessage(
        text: text,
        isMe: true,
        time: DateTime.now().toIso8601String(),
        id: '',
        imageUrl: '',
      );
      widget.onMessageSent(message);
      setState(() {
        _messages.insert(0, message);
      });
      _saveMessages();
      _messageController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Hero(
              tag: 'member_avatar_${_member.id}',
              child: CircleAvatar(
                backgroundImage: CachedNetworkImageProvider(_member.imageUrl),
                radius: 20,
              ),
            ),
            const SizedBox(width: 8),
            Text(_member.name),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              setState(() {
                _isEditing = !_isEditing;
              });
            },
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  if (_isEditing) _buildEditSection(context),
                  Expanded(
                    child: ListView.builder(
                      reverse: true,
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        return _buildMessageTile(message);
                      },
                    ),
                  ),
                  _buildChatInput(),
                ],
              ),
    );
  }

  Widget _buildEditSection(BuildContext context) {
    final nameController = TextEditingController(text: _member.name);
    final descriptionController = TextEditingController(
      text: _member.description,
    );

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          TextField(
            controller: descriptionController,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _member = Member(
                  id: _member.id,
                  name: nameController.text,
                  description: descriptionController.text,
                  imageUrl: _member.imageUrl,
                  company: _member.company,
                  location: _member.location,
                  alumniYear: _member.alumniYear,
                  role: _member.role,
                );
                _isEditing = false;
              });
              widget.onUpdateContacts(_member);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageTile(ChatMessage message) {
    return Align(
      alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(8.0),
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        decoration: BoxDecoration(
          color: message.isMe ? Colors.blue[100] : Colors.grey[200],
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Text(message.text),
      ),
    );
  }

  Widget _buildChatInput() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          IconButton(icon: const Icon(Icons.send), onPressed: _sendMessage),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String id;
  final String text;
  final bool isMe;
  final String time;
  final String imageUrl;

  ChatMessage({
    required this.text,
    required this.isMe,
    required this.time,
    this.id = '',
    this.imageUrl = '',
  });

  static String _safeString(dynamic value, String fallback) =>
      value is String ? value : fallback;

  ChatMessage.fromJson(Map<String, dynamic> json)
    : id = _safeString(json['id'], ''),
      text = _safeString(json['text'], ''),
      isMe = json['isMe'] ?? false,
      time = _safeString(json['time'], ''),
      imageUrl = _safeString(json['imageUrl'], '');

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'isMe': isMe,
    'time': time,
    'imageUrl': imageUrl,
  };

  getFormattedTime() {}
}

class Member {
  final String id;
  String name;
  String description;
  String imageUrl;
  String company;
  String location;
  String? alumniYear;
  String? role;

  Member({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.company,
    required this.location,
    this.alumniYear,
    this.role,
  });

  Member.fromJson(Map<String, dynamic> json)
    : id = json['id'],
      name = json['name'] ?? 'Unknown',
      description = json['description'] ?? '',
      imageUrl = json['imageUrl'] ?? 'https://via.placeholder.com/150',
      company = json['company'] ?? 'Unspecified',
      location = json['location'] ?? 'Unknown',
      alumniYear = json['alumniYear'],
      role = json['role'];

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'imageUrl': imageUrl,
    'company': company,
    'location': location,
    'alumniYear': alumniYear,
    'role': role,
  };
}

class MemberListScreen extends StatefulWidget {
  const MemberListScreen({super.key});

  @override
  State<MemberListScreen> createState() => _MemberListScreenState();
}

class _MemberListScreenState extends State<MemberListScreen> {
  List<Member> _members = [];
  bool _isLoading = true;
  String _currentUserId = 'defaultUser';

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
  }

  Future<void> _loadCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('currentUserId');
    if (userId == null) {
      userId = const Uuid().v4();
      await prefs.setString('currentUserId', userId);
      await prefs.setString('contacts', '{}');
      await prefs.setString('conversations', '{}');
    }
    setState(() {
      _currentUserId = userId!;
      _loadMembers();
    });
  }

  Future<void> _loadMembers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Simulate loading members from a data source (e.g., JSON file or API)
      await Future.delayed(const Duration(seconds: 1)); // Simulate delay
      final List<Member> loadedMembers = [
        Member(
          id: '1',
          name: 'Shaik Mohammad Muddassir',
          description: 'Software Engineer',
          imageUrl: 'https://via.placeholder.com/150',
          company: 'Google',
          location: 'New York',
          alumniYear: '2018',
          role: 'SWE',
        ),
        Member(
          id: '2',
          name: 'Chenji Nithin Kumar',
          description: 'Data Scientist',
          imageUrl: 'https://via.placeholder.com/150',
          company: 'Microsoft',
          location: 'Seattle',
          alumniYear: '2019',
          role: 'DS',
        ),
        Member(
          id: '3',
          name: 'Arigala Punith Kumar',
          description: 'Product Manager',
          imageUrl: 'https://via.placeholder.com/150',
          company: 'Amazon',
          location: 'San Francisco',
          alumniYear: '2020',
          role: 'PM',
        ),
      ];

      setState(() {
        _members = loadedMembers;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading members: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                itemCount: _members.length,
                itemBuilder: (context, index) {
                  final member = _members[index];
                  return MemberCard(
                    member: member,
                    currentUserId: _currentUserId,
                  );
                },
              ),
    );
  }
}
