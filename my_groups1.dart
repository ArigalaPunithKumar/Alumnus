import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:async'; // For Stream and Timer
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ArchivedGroupsScreen extends StatelessWidget {
  final List<Group> archivedGroups;

  const ArchivedGroupsScreen({super.key, required this.archivedGroups});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Archived Groups')),
      body: ListView.builder(
        itemCount: archivedGroups.length,
        itemBuilder: (context, index) {
          final group = archivedGroups[index];
          return GroupListItem(
            group: group,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(group: group),
                ),
              );
            },
            onJoinTap: () {},
          );
        },
      ),
    );
  }
}

class GroupListItem extends StatelessWidget {
  final Group group;
  final VoidCallback onTap;
  final VoidCallback onJoinTap;

  const GroupListItem({
    super.key,
    required this.group,
    required this.onTap,
    required this.onJoinTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 12.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        content: Image.network(group.profileImage),
                      );
                    },
                  );
                },
                child: Hero(
                  tag: 'group_image_${group.name}',
                  child: CircleAvatar(
                    backgroundImage: NetworkImage(group.profileImage),
                    radius: 30,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      group.lastMessage,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    group.time,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  if (group.isPinned)
                    const Icon(Icons.push_pin, size: 16, color: Colors.black54),
                  if (!group.isMember)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            group.isJoinRequested
                                ? Colors.grey
                                : Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(fontSize: 14),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      onPressed: group.isJoinRequested ? null : onJoinTap,
                      child: Text(group.isJoinRequested ? 'Requested' : 'Join'),
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

class ChatScreen extends StatefulWidget {
  final Group group;

  const ChatScreen({super.key, required this.group});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final StreamController<List<Message>> _messageStreamController =
      StreamController<List<Message>>.broadcast();
  late Stream<List<Message>> _messageStream;
  Timer? _simulatedMessageTimer;
  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _messageStream = _messageStreamController.stream;
    _loadMessages();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    _messageStreamController.add(List.from(widget.group.messages));
  }

  Future<void> _loadMessages() async {
    _prefs = await SharedPreferences.getInstance();
    final groupId = widget.group.name;
    final jsonString = _prefs.getString('messages_$groupId');

    if (jsonString != null) {
      final decoded = jsonDecode(jsonString) as List;
      widget.group.messages = decoded.map((i) => Message.fromJson(i)).toList();
    }

    _messageStreamController.add(List.from(widget.group.messages));
  }

  Future<void> _saveMessages() async {
    final groupId = widget.group.name;
    final jsonString = jsonEncode(
      widget.group.messages.map((e) => e.toJson()).toList(),
    );
    await _prefs.setString('messages_$groupId', jsonString);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _messageStreamController.close();
    _simulatedMessageTimer?.cancel();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  void _sendMessage() {
    if (_messageController.text.isNotEmpty) {
      final newMessage = Message(
        text: _messageController.text,
        sender: 'You',
        time: DateTime.now(),
        type: MessageType.text,
      );

      setState(() {
        widget.group.messages.add(newMessage);
        widget.group.lastMessage = _messageController.text;
      });

      _messageStreamController.add(List.from(widget.group.messages));
      _saveMessages();

      _messageController.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });

      _startSimulatedMessageTimer();
    }
  }

  void _simulateNewMessage() {
    final newMessage = Message(
      text: 'Simulated message!',
      sender: 'Other User',
      time: DateTime.now(),
      type: MessageType.text,
    );
    setState(() {
      widget.group.messages.add(newMessage);
    });

    _messageStreamController.add(List.from(widget.group.messages));
    _saveMessages();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _startSimulatedMessageTimer() {
    _simulatedMessageTimer?.cancel();
    _simulatedMessageTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        _simulateNewMessage();
      }
    });
  }

  Future<void> _openAttachmentOptions() async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.image, color: Colors.black87),
                title: const Text(
                  'Photo Gallery',
                  style: TextStyle(color: Colors.black87),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await _getImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.black87),
                title: const Text(
                  'Camera',
                  style: TextStyle(color: Colors.black87),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await _getImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.attach_file, color: Colors.black87),
                title: const Text(
                  'Document',
                  style: TextStyle(color: Colors.black87),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await _getDocument();
                },
              ),
              ListTile(
                leading: const Icon(Icons.mic, color: Colors.black87),
                title: const Text(
                  'Audio',
                  style: TextStyle(color: Colors.black87),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await _getAudio();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _getImage(ImageSource source) async {
    var status = await Permission.photos.status;
    if (!status.isGranted) {
      status = await Permission.photos.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission denied to access photos.')),
        );
        return;
      }
    }

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);

    if (image != null) {
      setState(() {
        final newMessage = Message(
          text: "Image",
          sender: 'You',
          time: DateTime.now(),
          type: MessageType.image,
          fileUrl: image.path,
        );
        widget.group.messages.add(newMessage);
        widget.group.media.add(
          MediaItem(
            thumbnailUrl: image.path,
            title: 'Image',
            subtitle: 'You',
            type: MediaType.image,
          ),
        );
        _saveMessages();
      });
    }
  }

  Future<void> _getAudio() async {
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permission denied to access microphone.'),
          ),
        );
        return;
      }
    }

    // Implement audio recording logic here
    // For example, using the sound_recorder package

    // After recording, add the audio message
    // setState(() {
    //   widget.group.messages.add(Message(
    //     text: "Audio",
    //     sender: 'You',
    //     time: DateTime.now(),
    //     type: MessageType.audio,
    //     fileUrl: 'path_to_recorded_audio', // Replace with actual path
    //   ));
    //   _saveMessages();
    // });
  }

  Future<void> _getDocument() async {
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      status = await Permission.storage.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission denied to access storage.')),
        );
        return;
      }
    }

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );

    if (result != null) {
      File file = File(result.files.single.path!);
      setState(() {
        final newMessage = Message(
          text: "Document",
          sender: 'You',
          time: DateTime.now(),
          type: MessageType.pdf,
          fileUrl: file.path,
        );
        widget.group.messages.add(newMessage);

        widget.group.media.add(
          MediaItem(
            thumbnailUrl: 'assets/document_icon.png',
            title: 'Document',
            subtitle: 'You',
            type: MediaType.document,
          ),
        );
        _saveMessages();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 70,
        leading: InkWell(
          onTap: () {
            Navigator.pop(context);
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.arrow_back, color: Colors.black87),
              Hero(
                tag: 'group_image_${widget.group.name}',
                child: CircleAvatar(
                  radius: 20,
                  backgroundImage: NetworkImage(widget.group.profileImage),
                ),
              ),
            ],
          ),
        ),
        title: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GroupInfoScreen(group: widget.group),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.group.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                widget.group.members.map((member) => member.name).join(', '),
                style: const TextStyle(fontSize: 12, color: Colors.black54),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call, color: Colors.black87),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.videocam, color: Colors.black87),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black87),
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(decoration: const BoxDecoration(color: Color(0xFFE8F5E9))),
          Column(
            children: [
              Expanded(
                child: StreamBuilder<List<Message>>(
                  stream: _messageStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return ListView.builder(
                        controller: _scrollController,
                        itemCount: snapshot.data!.length,
                        itemBuilder: (context, index) {
                          final message = snapshot.data![index];
                          return MessageBubble(message: message);
                        },
                      );
                    } else {
                      return const Center(child: Text("No messages yet"));
                    }
                  },
                ),
              ),
              _buildInputArea(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.attach_file, color: Colors.black87),
            onPressed: _openAttachmentOptions,
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    hintText: 'Message',
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  style: const TextStyle(color: Colors.black87),
                  onSubmitted: (text) {
                    _sendMessage();
                  },
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.send, color: Theme.of(context).primaryColor),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  final Message message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isMe = message.sender == 'You';
    final backgroundColor = isMe ? const Color(0xFFDCF8C6) : Colors.white;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(12.0),
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16.0),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.sender,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.black87,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            if (message.type == MessageType.text)
              Text(
                message.text,
                style: const TextStyle(color: Colors.black87, fontSize: 16),
              )
            else if (message.type == MessageType.image)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(message.fileUrl!),
                  width: 200,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              )
            else
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.file_present, color: Colors.black54),
                  SizedBox(width: 8),
                  Text('Document', style: TextStyle(color: Colors.black87)),
                ],
              ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                _formatMessageTime(message.time),
                style: const TextStyle(fontSize: 10, color: Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatMessageTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(time.year, time.month, time.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (messageDate == today) {
      return DateFormat('h:mm a').format(time);
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('MM/dd/yyyy').format(time);
    }
  }
}

class GroupInfoScreen extends StatefulWidget {
  final Group group;

  const GroupInfoScreen({super.key, required this.group});

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  bool chatLock = false;
  String _memberSearchQuery = '';
  final TextEditingController _memberSearchController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isEditingDescription = false;

  @override
  void initState() {
    super.initState();
    _descriptionController.text = widget.group.description;
  }

  @override
  void dispose() {
    _memberSearchController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  List<Member> get _filteredMembers {
    if (_memberSearchQuery.isEmpty) {
      return widget.group.members;
    } else {
      return widget.group.members
          .where(
            (member) => member.name.toLowerCase().contains(
              _memberSearchQuery.toLowerCase(),
            ),
          )
          .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            _memberSearchQuery.isEmpty
                ? const Text('Group Info')
                : _buildMemberSearchField(),
        actions: [
          if (_memberSearchQuery.isEmpty)
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                setState(() {
                  _memberSearchQuery = '';
                });
              },
            ),
          if (_memberSearchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _memberSearchQuery = '';
                  _memberSearchController.clear();
                });
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              content: Image.network(widget.group.profileImage),
                            );
                          },
                        );
                      },
                      child: Hero(
                        tag: 'group_image_${widget.group.name}',
                        child: CircleAvatar(
                          backgroundImage: NetworkImage(
                            widget.group.profileImage,
                          ),
                          radius: 50,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.group.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      'Group • ${widget.group.members.length} members',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child:
                        _isEditingDescription
                            ? TextFormField(
                              controller: _descriptionController,
                              decoration: const InputDecoration(
                                labelText: 'Group Description',
                                border: OutlineInputBorder(),
                              ),
                            )
                            : Text(
                              widget.group.description,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                            ),
                  ),
                  IconButton(
                    icon: Icon(
                      _isEditingDescription ? Icons.check : Icons.edit,
                      color: Theme.of(context).primaryColor,
                    ),
                    onPressed: () {
                      setState(() {
                        if (_isEditingDescription) {
                          widget.group.description =
                              _descriptionController.text;
                        }
                        _isEditingDescription = !_isEditingDescription;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.mic,
                          size: 30,
                          color: Colors.black87,
                        ),
                        onPressed: () {},
                      ),
                      const Text(
                        "Voice Chat",
                        style: TextStyle(color: Colors.black87),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.person_add,
                          size: 30,
                          color: Colors.black87,
                        ),
                        onPressed: () {},
                      ),
                      const Text(
                        "Add",
                        style: TextStyle(color: Colors.black87),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.search,
                          size: 30,
                          color: Colors.black87,
                        ),
                        onPressed: () {},
                      ),
                      const Text(
                        "Search",
                        style: TextStyle(color: Colors.black87),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.notifications, color: Colors.black87),
                title: const Text(
                  'Notifications',
                  style: TextStyle(color: Colors.black87),
                ),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.visibility, color: Colors.black87),
                title: const Text(
                  'Media visibility',
                  style: TextStyle(color: Colors.black87),
                ),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.lock, color: Colors.black87),
                title: const Text(
                  'Encryption',
                  style: TextStyle(color: Colors.black87),
                ),
                subtitle: const Text(
                  'Messages and calls are end-to-end encrypted. Tap to learn more.',
                  style: TextStyle(color: Colors.black54),
                ),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.chat_bubble, color: Colors.black87),
                title: const Text(
                  'Chat lock',
                  style: TextStyle(color: Colors.black87),
                ),
                subtitle: const Text(
                  'Lock and hide this chat on this device.',
                  style: TextStyle(color: Colors.black54),
                ),
                trailing: Switch(
                  activeColor: Theme.of(context).primaryColor,
                  value: chatLock,
                  onChanged: (value) {
                    setState(() {
                      chatLock = value;
                    });
                  },
                ),
                onTap: () {},
              ),
              const SizedBox(height: 10),
              Text(
                '${widget.group.members.length} members',
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredMembers.length,
                itemBuilder: (context, index) {
                  final member = _filteredMembers[index];
                  return Card(
                    elevation: 1,
                    margin: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 0,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListTile(
                      leading: GestureDetector(
                        onTap: () {
                          // show update prompt
                        },
                        child: Stack(
                          children: [
                            const CircleAvatar(
                              backgroundColor: Colors.amber,
                              child: Icon(Icons.face, color: Colors.white),
                            ),
                            Positioned(
                              bottom: -2,
                              right: -2,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  // view profile
                                },
                                icon: const Icon(
                                  Icons.edit,
                                  size: 20,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      title: Text(
                        member.name,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        member.phoneNumber ?? '+91 84899 08432',
                        style: const TextStyle(color: Colors.black54),
                      ),
                      trailing:
                          member.isAdmin
                              ? Chip(
                                label: const Text(
                                  'Group Admin',
                                  style: TextStyle(color: Colors.white),
                                ),
                                backgroundColor: Theme.of(context).primaryColor,
                              )
                              : null,
                      onTap: () {},
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text(
                            "Leave Group?",
                            style: TextStyle(color: Colors.black87),
                          ),
                          content: const Text(
                            "Are you sure you want to leave this group?",
                            style: TextStyle(color: Colors.black87),
                          ),
                          actions: [
                            TextButton(
                              child: const Text(
                                "Cancel",
                                style: TextStyle(color: Colors.black87),
                              ),
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                            ),
                            TextButton(
                              child: const Text(
                                "Leave",
                                style: TextStyle(color: Colors.redAccent),
                              ),
                              onPressed: () {
                                Navigator.of(context).pop();
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('You have left the group.'),
                                  ),
                                );
                              },
                            ),
                          ],
                        );
                      },
                    );
                  },
                  child: const Text('Leave Group'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMemberSearchField() {
    return TextField(
      controller: _memberSearchController,
      autofocus: true,
      decoration: InputDecoration(
        hintText: 'Search members...',
        hintStyle: const TextStyle(color: Colors.grey),
        border: InputBorder.none,
        prefixIcon: const Icon(Icons.search, color: Colors.grey),
        suffixIcon: IconButton(
          icon: const Icon(Icons.clear, color: Colors.grey),
          onPressed: () {
            setState(() {
              _memberSearchQuery = '';
              _memberSearchController.clear();
            });
          },
        ),
      ),
      style: const TextStyle(color: Colors.black87, fontSize: 16),
      onChanged: (value) {
        setState(() {
          _memberSearchQuery = value;
        });
      },
    );
  }
}

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _groupDescriptionController =
      TextEditingController();
  File? _groupImage;
  final List<Member> _selectedMembers = [];

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    setState(() {
      if (image != null) {
        _groupImage = File(image.path);
      } else {
        _groupImage = null;
      }
    });
  }

  Future<void> _selectMembers(BuildContext context) async {
    List<Member> allMembers = [
      Member(
        name: 'George Smith',
        isAdmin: true,
        imageUrl: 'https://example.com/george.jpg',
        id: 'george-123',
        description: 'Software Engineer',
        company: 'TechCorp',
        location: 'New York, NY',
      ),
      Member(
        name: 'Sophia Clark',
        imageUrl: 'https://example.com/sophia.jpg',
        id: 'sophia-456',
        description: 'Product Manager',
        company: 'Innovate Inc.',
        location: 'San Francisco, CA',
      ),
      Member(
        name: 'Henry Taylor',
        imageUrl: 'https://example.com/henry.jpg',
        id: 'henry-789',
        description: 'Data Scientist',
        company: 'Analytics Co.',
        location: 'London, UK',
      ),
      Member(
        name: 'Elizbeth zordan',
        imageUrl: 'https://example.com/henry.jpg',
        id: 'zordan-543',
        description: 'Data Scientist',
        company: 'Analytics Co.',
        location: 'London, UK',
      ),
    ];

    List<Member>? selected = await showDialog<List<Member>>(
      context: context,
      builder: (BuildContext context) {
        return MemberSelectionDialog(
          allMembers: allMembers,
          selectedMembers: _selectedMembers,
        );
      },
    );

    if (selected != null) {
      setState(() {
        _selectedMembers.clear();
        _selectedMembers.addAll(selected);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Group')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Center(
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage:
                      _groupImage != null ? FileImage(_groupImage!) : null,
                  child:
                      _groupImage == null
                          ? const Icon(Icons.camera_alt, size: 40)
                          : null,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _groupNameController,
              decoration: const InputDecoration(
                labelText: 'Group Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _groupDescriptionController,
              decoration: const InputDecoration(
                labelText: 'Group Description',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _selectMembers(context),
              child: const Text('Select Members'),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              children:
                  _selectedMembers
                      .map(
                        (member) => Chip(
                          label: Text(member.name),
                          onDeleted: () {
                            setState(() {
                              _selectedMembers.remove(member);
                            });
                          },
                        ),
                      )
                      .toList(),
            ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  String groupName = _groupNameController.text;
                  String groupDescription = _groupDescriptionController.text;
                  if (groupName.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Group name cannot be empty.'),
                      ),
                    );
                    return;
                  }

                  if (_selectedMembers.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please select at least one member.'),
                      ),
                    );
                    return;
                  }

                  Group newGroup = Group(
                    name: groupName,
                    description: groupDescription,
                    profileImage:
                        'https://source.unsplash.com/random/150x150?group',
                    lastMessage: 'No messages yet',
                    time: 'Now',
                    messages: [],
                    media: [],
                    members: _selectedMembers,
                    isJoinRequested: false,
                  );

                  Navigator.pop(context, newGroup);
                },
                child: const Text('Create Group'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MemberSelectionDialog extends StatefulWidget {
  final List<Member> allMembers;
  final List<Member> selectedMembers;

  const MemberSelectionDialog({
    super.key,
    required this.allMembers,
    required this.selectedMembers,
  });

  @override
  State<MemberSelectionDialog> createState() => _MemberSelectionDialogState();
}

class _MemberSelectionDialogState extends State<MemberSelectionDialog> {
  late List<bool> _isChecked;

  @override
  void initState() {
    super.initState();
    _isChecked = List<bool>.filled(widget.allMembers.length, false);
    for (int i = 0; i < widget.allMembers.length; i++) {
      if (widget.selectedMembers.contains(widget.allMembers[i])) {
        _isChecked[i] = true;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Select Members',
        style: TextStyle(color: Colors.black87),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: widget.allMembers.length,
          itemBuilder: (context, index) {
            return CheckboxListTile(
              title: Text(
                widget.allMembers[index].name,
                style: const TextStyle(color: Colors.black87),
              ),
              value: _isChecked[index],
              onChanged: (bool? value) {
                setState(() {
                  _isChecked[index] = value!;
                });
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          child: const Text('Cancel', style: TextStyle(color: Colors.black87)),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        ElevatedButton(
          child: const Text('Select'),
          onPressed: () {
            List<Member> selected = [];
            for (int i = 0; i < widget.allMembers.length; i++) {
              if (_isChecked[i]) {
                selected.add(widget.allMembers[i]);
              }
            }
            Navigator.of(context).pop(selected);
          },
        ),
      ],
    );
  }
}

class Group {
  final String name;
  String description;
  final String profileImage;
  String lastMessage;
  final String time;
  bool isPinned;
  List<Message> messages;
  List<MediaItem> media;
  bool chatLockEnabled;
  List<Member> members;
  bool isJoinRequested;
  bool isMember;

  Group({
    required this.name,
    required this.description,
    required this.profileImage,
    required this.lastMessage,
    required this.time,
    this.isPinned = false,
    required this.messages,
    required this.media,
    this.chatLockEnabled = false,
    required this.members,
    required this.isJoinRequested,
    this.isMember = false,
  });
}

class Member {
  final String name;
  final String? phoneNumber;
  final bool isAdmin;
  final String? profilePictureUrl;
  final String id;
  final String description;
  final String imageUrl;
  final String company;
  final String location;

  Member({
    required this.name,
    this.phoneNumber,
    this.isAdmin = false,
    this.profilePictureUrl,
    required this.id,
    required this.description,
    required this.imageUrl,
    required this.company,
    required this.location,
  });

  // Add toJson method
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phoneNumber': phoneNumber,
      'isAdmin': isAdmin,
      'profilePictureUrl': profilePictureUrl,
      'id': id,
      'description': description,
      'imageUrl': imageUrl,
      'company': company,
      'location': location,
    };
  }

  // Add fromJson method
  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      name: json['name'],
      phoneNumber: json['phoneNumber'],
      isAdmin: json['isAdmin'],
      profilePictureUrl: json['profilePictureUrl'],
      id: json['id'],
      description: json['description'],
      imageUrl: json['imageUrl'],
      company: json['company'],
      location: json['location'],
    );
  }
}

class Message {
  final String text;
  final String sender;
  final DateTime time;
  final MessageType type;
  final String? fileUrl;
  final String? fileSize;

  Message({
    required this.text,
    required this.sender,
    required this.time,
    required this.type,
    this.fileUrl,
    this.fileSize,
  });

  // Add toJson method
  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'sender': sender,
      'time': time.toIso8601String(),
      'type': type.index, // Store enum index
      'fileUrl': fileUrl,
      'fileSize': fileSize,
    };
  }

  // Add fromJson method
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      text: json['text'],
      sender: json['sender'],
      time: DateTime.parse(json['time']),
      type: MessageType.values[json['type']], // Retrieve enum from index
      fileUrl: json['fileUrl'],
      fileSize: json['fileSize'],
    );
  }
}

enum MessageType { text, image, pdf, audio }

class MediaItem {
  final String thumbnailUrl;
  final String title;
  final String subtitle;
  final MediaType type;

  MediaItem({
    required this.thumbnailUrl,
    required this.title,
    required this.subtitle,
    required this.type,
  });
}

enum MediaType { image, link, document }
