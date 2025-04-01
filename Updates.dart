import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Enhanced Chat App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const ProfileUpdatesScreen(memberId: 'user123'),
    );
  }
}

class ProfileUpdatesScreen extends StatefulWidget {
  final String memberId;

  const ProfileUpdatesScreen({super.key, required this.memberId});

  @override
  State<ProfileUpdatesScreen> createState() => _ProfileUpdatesScreenState();
}

class _ProfileUpdatesScreenState extends State<ProfileUpdatesScreen> {
  Map<String, List<UpdateItem>> _allUpdates = {};
  Timer? _expirationTimer;

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
    // Check for expired posts every minute
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
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('updates') ?? '{}';

    try {
      final Map<String, dynamic> decodedData = jsonDecode(jsonString);
      setState(() {
        _allUpdates = decodedData.map((key, value) {
          final List<dynamic> updateList = value as List<dynamic>;
          return MapEntry(
            key,
            updateList.map((item) => UpdateItem.fromJson(item)).toList(),
          );
        });
      });
      _checkExpiredPosts(); // Check immediately after loading
    } catch (e) {
      setState(() {
        _allUpdates = {};
      });
      await prefs.setString('updates', '{}');
      print('Error loading updates: $e');
    }
  }

  List<UpdateItem> get _userUpdates {
    return _allUpdates[widget.memberId]
            ?.where((update) => !update.isExpired)
            .toList() ??
        [];
  }

  Future<void> _saveUpdates() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> jsonData = {};

    _allUpdates.forEach((key, value) {
      jsonData[key] = value.map((item) => item.toJson()).toList();
    });

    await prefs.setString('updates', jsonEncode(jsonData));
  }

  void _openNewUpdateDialog() async {
    final result = await showDialog(
      context: context,
      builder: (BuildContext context) => const NewUpdateDialog(),
    );

    if (result != null && result is UpdateItem) {
      setState(() {
        _allUpdates.putIfAbsent(widget.memberId, () => []);
        _allUpdates[widget.memberId]!.insert(0, result);
        _saveUpdates();
      });
    }
  }

  void _deletePost(int index) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Post'),
          content: const Text('Are you sure you want to delete this post?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _allUpdates[widget.memberId]!.removeAt(index);
                  if (_allUpdates[widget.memberId]!.isEmpty) {
                    _allUpdates.remove(widget.memberId);
                  }
                  _saveUpdates();
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Post deleted successfully'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Updates'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: FloatingActionButton(
              mini: true,
              elevation: 0,
              backgroundColor: Theme.of(context).colorScheme.primary,
              onPressed: _openNewUpdateDialog,
              child: const Icon(Icons.add, size: 24),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child:
                _userUpdates.isEmpty
                    ? const Center(
                      child: Text(
                        'No updates yet\nTap the + button to share something',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    )
                    : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _userUpdates.length,
                      separatorBuilder:
                          (context, index) => const SizedBox(height: 16),
                      itemBuilder:
                          (context, index) =>
                              _buildUpdateCard(_userUpdates[index], index),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateCard(UpdateItem update, int index) {
    final isMediaPost = update.imageUrl != null || update.videoUrl != null;

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
                  child: Text(
                    update.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
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
                IconButton(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onPressed: () => _showPostOptions(context, index),
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
              VideoDisplay(
                videoUrl: update.videoUrl!,
                onDelete: () => _deletePost(index),
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
                  onTap: () => _toggleLike(index),
                ),
                _buildInteractionButton(
                  icon:
                      update.isDisliked
                          ? Icons.thumb_down
                          : Icons.thumb_down_outlined,
                  label: 'Dislike',
                  isActive: update.isDisliked,
                  onTap: () => _toggleDislike(index),
                ),
                _buildInteractionButton(
                  icon: Icons.report_outlined,
                  label: 'Report',
                  onTap: () => _reportPost(index),
                ),
              ],
            ),
            if (update.status != null)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _buildMessageStatus(update.status!),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageStatus(MessageStatus status) {
    IconData icon;
    Color color;

    switch (status) {
      case MessageStatus.sent:
        icon = Icons.check;
        color = Colors.grey;
        break;
      case MessageStatus.delivered:
        icon = Icons.check;
        color = Colors.grey;
        break;
      case MessageStatus.read:
        icon = Icons.done_all;
        color = Colors.blue;
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatMessageStatus(status),
          style: TextStyle(color: color, fontSize: 12),
        ),
        const SizedBox(width: 4),
        Icon(icon, size: 16, color: color),
      ],
    );
  }

  String _formatMessageStatus(MessageStatus status) {
    switch (status) {
      case MessageStatus.sent:
        return 'Sent';
      case MessageStatus.delivered:
        return 'Delivered';
      case MessageStatus.read:
        return 'Read';
    }
  }

  void _showPostOptions(BuildContext context, int index) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Delete Post',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deletePost(index);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Post'),
                onTap: () {
                  Navigator.pop(context);
                  // Implement edit functionality if needed
                },
              ),
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('Share Post'),
                onTap: () {
                  Navigator.pop(context);
                  // Implement share functionality
                },
              ),
            ],
          ),
        );
      },
    );
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

  void _toggleLike(int index) {
    setState(() {
      final update = _userUpdates[index];
      update.isLiked = !update.isLiked;
      if (update.isLiked) update.isDisliked = false;
      _saveUpdates();
    });
  }

  void _toggleDislike(int index) {
    setState(() {
      final update = _userUpdates[index];
      update.isDisliked = !update.isDisliked;
      if (update.isDisliked) update.isLiked = false;
      _saveUpdates();
    });
  }

  void _reportPost(int index) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Report Post'),
            content: const Text(
              'This post will be reviewed by our team. Thank you for helping us keep the community safe.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Post reported successfully'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: const Text(
                  'Report',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
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
  int _expirationDays = 7; // Default expiration in 7 days

  Future<void> _pickMedia(bool isImage) async {
    final picker = ImagePicker();
    final XFile? pickedFile =
        isImage
            ? await picker.pickImage(source: ImageSource.gallery)
            : await picker.pickVideo(source: ImageSource.gallery);

    setState(() {
      if (pickedFile != null) {
        if (isImage) {
          _image = File(pickedFile.path);
          _video = null;
        } else {
          _video = pickedFile.path;
          _image = null;
        }
      }
    });
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
  bool isLiked;
  bool isDisliked;
  bool isExpired;
  MessageStatus? status;
  final DateTime? expirationDate;

  UpdateItem({
    required this.title,
    required this.description,
    required this.time,
    required this.icon,
    this.imageUrl,
    this.videoUrl,
    this.isLiked = false,
    this.isDisliked = false,
    this.isExpired = false,
    this.status,
    this.expirationDate,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'time': time,
    'icon': icon.codePoint,
    'imageUrl': imageUrl,
    'videoUrl': videoUrl,
    'isLiked': isLiked,
    'isDisliked': isDisliked,
    'isExpired': isExpired,
    'status': status?.index,
    'expirationDate': expirationDate?.toIso8601String(),
  };

  factory UpdateItem.fromJson(Map<String, dynamic> json) => UpdateItem(
    title: json['title'],
    description: json['description'],
    time: json['time'],
    icon: IconData(json['icon'], fontFamily: 'MaterialIcons'),
    imageUrl: json['imageUrl'],
    videoUrl: json['videoUrl'],
    isLiked: json['isLiked'] ?? false,
    isDisliked: json['isDisliked'] ?? false,
    isExpired: json['isExpired'] ?? false,
    status:
        json['status'] != null ? MessageStatus.values[json['status']] : null,
    expirationDate:
        json['expirationDate'] != null
            ? DateTime.parse(json['expirationDate'])
            : null,
  );
}

enum MessageStatus { sent, delivered, read }

class VideoDisplay extends StatefulWidget {
  final String videoUrl;
  final VoidCallback onDelete;

  const VideoDisplay({
    super.key,
    required this.videoUrl,
    required this.onDelete,
  });

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
