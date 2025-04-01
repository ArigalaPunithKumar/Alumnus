import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:animate_do/animate_do.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'BottomNavigation.dart';
import 'my_groups.dart';
import 'Updates.dart';

void main() {
  runApp(const HomeScreen());
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mohan Babu University Alumni',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4)),
      ),
      home: const MemberListScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
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

  Member copyWith({
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    String? company,
    String? location,
    String? alumniYear,
    String? role,
  }) {
    return Member(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      company: company ?? this.company,
      location: location ?? this.location,
      alumniYear: alumniYear ?? this.alumniYear,
      role: role ?? this.role,
    );
  }

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      imageUrl: json['imageUrl'] as String,
      company: json['company'] as String,
      location: json['location'] as String,
      alumniYear: json['alumniYear'] as String?,
      role: json['role'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
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

  @override
  String toString() {
    return 'Member{id: $id, name: $name, description: $description, imageUrl: $imageUrl, company: $company, location: $location, alumniYear: $alumniYear, role: $role}';
  }
}

class MemberListScreen extends StatefulWidget {
  const MemberListScreen({super.key});

  @override
  State<MemberListScreen> createState() => _MemberListScreenState();
}

class _MemberListScreenState extends State<MemberListScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  List<Member> _members = [];
  String _searchQuery = '';
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  List<String> _selectedCompanies = [];
  List<String> _selectedLocations = [];
  late AnimationController _animationController;
  late Animation<double> _animation;

  // Added User ID for unique Chat Key
  String _currentUserId = 'defaultUser';

  @override
  void initState() {
    super.initState();
    _loadMembers();
    _loadCurrentUserId();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
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
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _members = List.from(memberData);
      _isLoading = false;
      _animationController.forward();
    });
  }

  List<Member> get _filteredMembers {
    List<Member> filteredList = List.from(_members);

    if (_searchQuery.isNotEmpty) {
      final lowerQuery = _searchQuery.toLowerCase();
      filteredList =
          filteredList
              .where(
                (member) =>
                    member.name.toLowerCase().contains(lowerQuery) ||
                    member.description.toLowerCase().contains(lowerQuery) ||
                    member.company.toLowerCase().contains(lowerQuery),
              )
              .toList();
    }

    if (_selectedCompanies.isNotEmpty) {
      filteredList =
          filteredList
              .where((member) => _selectedCompanies.contains(member.company))
              .toList();
    }

    if (_selectedLocations.isNotEmpty) {
      filteredList =
          filteredList
              .where((member) => _selectedLocations.contains(member.location))
              .toList();
    }

    return filteredList;
  }

  void _selectCategory(String category) {
    setState(() {
      if (category == 'Company') {
        _showCompanyFilterDialog(context);
      } else if (category == 'Location') {
        _showLocationFilterDialog(context);
      } else if (category == 'My Groups') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => ResponsiveBuilder(
                  builder: (context, sizingInformation) {
                    return GroupListScreen(
                      deviceScreenType: sizingInformation.deviceScreenType,
                    );
                  },
                ),
          ),
        );
      }
    });
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return const MoreOptionsBottomSheet();
      },
    );
  }

  Future<void> _showCompanyFilterDialog(BuildContext context) async {
    final availableCompanies = _members.map((m) => m.company).toSet().toList();
    List<String> tempSelectedCompanies = List.from(_selectedCompanies);

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Filter by Company'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children:
                      availableCompanies
                          .map(
                            (company) => CheckboxListTile(
                              title: Text(company),
                              value: tempSelectedCompanies.contains(company),
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value == true) {
                                    tempSelectedCompanies.add(company);
                                  } else {
                                    tempSelectedCompanies.remove(company);
                                  }
                                });
                              },
                            ),
                          )
                          .toList(),
                ),
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Apply'),
              onPressed: () {
                setState(() {
                  _selectedCompanies = List.from(tempSelectedCompanies);
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showLocationFilterDialog(BuildContext context) async {
    final availableLocations = _members.map((m) => m.location).toSet().toList();
    List<String> tempSelectedLocations = List.from(_selectedLocations);

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Filter by Location'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children:
                      availableLocations
                          .map(
                            (location) => CheckboxListTile(
                              title: Text(location),
                              value: tempSelectedLocations.contains(location),
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value == true) {
                                    tempSelectedLocations.add(location);
                                  } else {
                                    tempSelectedLocations.remove(location);
                                  }
                                });
                              },
                            ),
                          )
                          .toList(),
                ),
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Apply'),
              onPressed: () {
                setState(() {
                  _selectedLocations = List.from(tempSelectedLocations);
                });
                Navigator.of(context).pop();
              },
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
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return FadeTransition(
            opacity: _animation,
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            Theme.of(context).colorScheme.surface,
                          ],
                        ),
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText:
                                    'Search by Name, Company, or Description',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                    });
                                  },
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _searchQuery = value;
                                });
                              },
                            ),
                          ),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildCategoryButton(
                                  Icons.business,
                                  'Company',
                                  () => _selectCategory('Company'),
                                ),
                                _buildCategoryButton(
                                  Icons.location_on,
                                  'Location',
                                  () => _selectCategory('Location'),
                                ),
                                _buildCategoryButton(
                                  Icons.groups,
                                  'My Groups',
                                  () => _selectCategory('My Groups'),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8.0,
                              horizontal: 16.0,
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Top alumni profiles',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child:
                                _filteredMembers.isEmpty
                                    ? const Center(
                                      child: Text("No members found."),
                                    )
                                    : GridView.builder(
                                      gridDelegate:
                                          const SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: 1,
                                            childAspectRatio: 4,
                                          ),
                                      itemCount: _filteredMembers.length,
                                      itemBuilder: (context, index) {
                                        return FadeInUp(
                                          delay: Duration(
                                            milliseconds: 100 * index,
                                          ),
                                          child: _buildMemberCard(
                                            _filteredMembers[index],
                                          ),
                                        );
                                      },
                                    ),
                          ),
                        ],
                      ),
                    ),
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
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
        onTap: (int index) {
          setState(() {
            _selectedIndex = index;
          });

          switch (index) {
            case 4:
              _showMoreOptions(context);
              break;
            case 1:
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const UpdatesScreen()),
              );
              break;
            case 2:
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MessagesScreen()),
              );
              break;
            case 3:
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(),
                ),
              );
              break;
            case 0:
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
              );
              break;
          }
        },
      ),
    );
  }

  Widget _buildCategoryButton(
    IconData icon,
    String label,
    VoidCallback onPressed,
  ) {
    final List<Color> buttonBackgroundColors = [
      Colors.amber.shade200,
      Colors.deepPurple.shade200,
      Colors.lightGreen.shade200,
      Colors.blueGrey.shade200,
    ];

    final randomBackgroundColor =
        buttonBackgroundColors[DateTime.now().microsecond %
            buttonBackgroundColors.length];

    final List<Color> buttonTextColors = [
      const Color.fromARGB(221, 0, 0, 0),
      const Color.fromARGB(255, 56, 38, 55),
      const Color.fromARGB(255, 146, 27, 140),
    ];

    final randomTextColor =
        buttonTextColors[DateTime.now().microsecond % buttonTextColors.length];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: randomBackgroundColor,
          foregroundColor: randomTextColor,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          textStyle: const TextStyle(fontSize: 12),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 4.0),
            Text(label),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberCard(Member member) {
    final List<Color> buttonColors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
    ];

    final randomColor =
        buttonColors[DateTime.now().microsecond % buttonColors.length];

    return Card(
      margin: const EdgeInsets.all(8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => MemberDetailsScreen(
                    member: member,
                    onMemberUpdated: (updatedMember) {
                      setState(() {
                        final index = _members.indexWhere(
                          (m) => m.id == member.id,
                        );
                        if (index != -1) {
                          _members[index] = updatedMember;
                        }
                      });
                    },
                  ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundImage: CachedNetworkImageProvider(member.imageUrl),
                onBackgroundImageError: (exception, stackTrace) {
                  print('Image load error: $exception');
                },
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name.length > 30
                          ? '${member.name.substring(0, 30)}...'
                          : member.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      member.description.length > 50
                          ? '${member.description.substring(0, 50)}...'
                          : member.description,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => ChatScreen(
                            currentUserId: _currentUserId,
                            member: member,
                            onMessageSent: (ChatMessage newMessage) {
                              print('New message sent: ${newMessage.text}');
                            },
                            onUpdateContacts: (Member updatedMember) {
                              setState(() {
                                final index = _members.indexWhere(
                                  (m) => m.id == updatedMember.id,
                                );
                                if (index != -1) {
                                  _members[index] = updatedMember;
                                }
                              });
                            },
                          ),
                    ),
                  );
                },
                icon: const Icon(Icons.person_add),
                label: const Text('Connect'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: randomColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  minimumSize: const Size(70, 30),
                  textStyle: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MemberDetailsScreen extends StatelessWidget {
  final Member member;
  final Function(Member) onMemberUpdated;

  const MemberDetailsScreen({
    super.key,
    required this.member,
    required this.onMemberUpdated,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        title: Text(member.name),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Hero(
                tag: 'member_image_${member.id}',
                child: CircleAvatar(
                  radius: 80,
                  backgroundImage: CachedNetworkImageProvider(member.imageUrl),
                  onBackgroundImageError: (exception, stackTrace) {
                    print('Image load error: $exception');
                  },
                ),
              ),
              const SizedBox(height: 20),
              Text(
                member.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Description:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(member.description, textAlign: TextAlign.center),
                    const SizedBox(height: 10),
                    Text(
                      'Company: ${member.company}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Location: ${member.location}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) =>
                              ProfileUpdatesScreen(memberId: member.id),
                    ),
                  );
                },
                icon: const Icon(Icons.update),
                label: const Text('View Updates'),
              ),
            ],
          ),
        ),
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
    required this.id,
    required this.text,
    required this.isMe,
    required this.time,
    required this.imageUrl,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      text: json['text'] as String,
      isMe: json['isMe'] as bool,
      time: json['time'] as String,
      imageUrl: json['imageUrl'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'isMe': isMe,
      'time': time,
      'imageUrl': imageUrl,
    };
  }

  String getFormattedTime() {
    try {
      final dateTime = DateTime.parse(time);
      return DateFormat('h:mm a').format(dateTime);
    } catch (e) {
      print("Error parsing date: $time, Error: $e");
      return time;
    }
  }

  @override
  String toString() {
    return 'ChatMessage{id: $id, text: $text, isMe: $isMe, time: $time, imageUrl: $imageUrl}';
  }
}

// Inside ChatScreen, include ChatKey
class ChatScreen extends StatefulWidget {
  final String currentUserId;
  final Member member;
  final Function(ChatMessage) onMessageSent;
  final Function(Member) onUpdateContacts;

  const ChatScreen({
    super.key,
    required this.currentUserId,
    required this.member,
    required this.onMessageSent,
    required this.onUpdateContacts,
  });

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

// Inside ChatScreen State, you dont have to mention chatkey here as we already implemented in messages section
class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  WebSocketChannel? channel;
  bool _connected = false;
  Timer? _replyTimer;
  bool _isLoadingHistory = true;

  String get _chatHistoryKey =>
      'chatHistory_${widget.currentUserId}_${widget.member.id}';

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
    _connectWebSocket();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    channel?.sink.close();
    _replyTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadChatHistory() async {
    setState(() {
      _isLoadingHistory = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? historyJson = prefs.getStringList(_chatHistoryKey);

      if (historyJson != null) {
        final loadedMessages =
            historyJson
                .map((jsonString) {
                  try {
                    return ChatMessage.fromJson(jsonDecode(jsonString));
                  } catch (e) {
                    print("Error decoding message: $jsonString, Error: $e");
                    return null;
                  }
                })
                .whereType<ChatMessage>()
                .toList();

        loadedMessages.sort((a, b) => a.time.compareTo(b.time));

        setState(() {
          _messages.addAll(loadedMessages);
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom(instant: true);
        });
      }
    } catch (e) {
      print("Error loading chat history: $e");
    } finally {
      setState(() {
        _isLoadingHistory = false;
      });
    }
  }

  Future<void> _saveChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> historyJson =
          _messages.map((msg) => jsonEncode(msg.toJson())).toList();
      await prefs.setStringList(_chatHistoryKey, historyJson);
    } catch (e) {
      print("Error saving chat history: $e");
    }
  }

  Future<void> _connectWebSocket() async {
    try {
      channel = WebSocketChannel.connect(
        Uri.parse('wss://echo.websocket.events'),
      );
      setState(() {
        _connected = true;
      });

      channel!.stream.listen(
        (message) {
          _handleReceivedMessage(message);
        },
        onError: (error) {
          print('WebSocket error: $error');
          setState(() {
            _connected = false;
          });
        },
        onDone: () {
          setState(() {
            _connected = false;
          });
        },
      );
    } catch (e) {
      setState(() {
        _connected = false;
      });
    }
  }

  void _handleReceivedMessage(dynamic message) {
    ChatMessage newMessage;
    try {
      final decodedMessage = jsonDecode(message);
      newMessage = ChatMessage(
        id: const Uuid().v4(),
        text: decodedMessage['text'] ?? 'Received invalid message',
        isMe: false,
        time: decodedMessage['time'] ?? DateTime.now().toIso8601String(),
        imageUrl: widget.member.imageUrl,
      );
    } catch (e) {
      newMessage = ChatMessage(
        id: const Uuid().v4(),
        text: message.toString(),
        isMe: false,
        time: DateTime.now().toIso8601String(),
        imageUrl: widget.member.imageUrl,
      );
    }

    if (mounted) {
      setState(() {
        _messages.add(newMessage);
      });
      _saveChatHistory();
      _scrollToBottom();
    }
  }

  void _scrollToBottom({bool instant = false}) {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      if (instant) {
        _scrollController.jumpTo(maxScroll);
      } else {
        _scrollController.animateTo(
          maxScroll,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          final maxScroll = _scrollController.position.maxScrollExtent;
          if (instant) {
            _scrollController.jumpTo(maxScroll);
          } else {
            _scrollController.animateTo(
              maxScroll,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        }
      });
    }
  }

  void _sendMessage() {
    if (_messageController.text.trim().isNotEmpty) {
      final now = DateTime.now();
      final newMessage = ChatMessage(
        id: const Uuid().v4(),
        text: _messageController.text.trim(),
        isMe: true,
        time: now.toIso8601String(),
        imageUrl: '',
      );

      setState(() {
        _messages.add(newMessage);
        _messageController.clear();
      });

      _saveChatHistory();
      widget.onMessageSent(newMessage);

      if (_connected && channel != null) {
        try {
          channel!.sink.add(
            jsonEncode({'text': newMessage.text, 'time': newMessage.time}),
          );
          _simulateReply();
        } catch (e) {
          print("Error sending message via WebSocket: $e");
        }
      } else {
        print('Not connected to WebSocket, message saved locally.');
        _simulateReply();
      }
      _scrollToBottom();
    }
  }

  void _simulateReply() {
    _replyTimer?.cancel();
    _replyTimer = Timer(const Duration(seconds: 1), () {
      if (!mounted) return;

      final lastSentMessage = _messages.lastWhere(
        (m) => m.isMe,
        orElse: () => _messages.first,
      );
      final replyText = 'Echo: ${lastSentMessage.text}';

      final replyMessage = ChatMessage(
        id: const Uuid().v4(),
        text: replyText,
        isMe: false,
        time: DateTime.now().toIso8601String(),
        imageUrl: widget.member.imageUrl,
      );

      if (mounted) {
        setState(() {
          _messages.add(replyMessage);
        });
        _saveChatHistory();
        _scrollToBottom();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: CachedNetworkImageProvider(
                widget.member.imageUrl,
              ),
              onBackgroundImageError: (exception, stackTrace) {
                print('AppBar Avatar load error: $exception');
              },
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.member.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (String item) {
              switch (item) {
                case 'Edit Profile':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => EditMemberDetailsScreen(
                            member: widget.member,
                            onMemberUpdated: (updatedMember) {
                              widget.onUpdateContacts(updatedMember);
                              setState(() {});
                            },
                          ),
                    ),
                  );
                  break;
                case 'Clear Chat':
                  _clearChatConfirmation();
                  break;
                case 'Block or Report':
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Block/Report action (not implemented)'),
                    ),
                  );
                  break;
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem<String>(
                  value: 'Edit Profile',
                  child: Text('View/Edit Contact'),
                ),
                const PopupMenuItem<String>(
                  value: 'Clear Chat',
                  child: Text('Clear Chat'),
                ),
                const PopupMenuItem<String>(
                  value: 'Block or Report',
                  child: Text('Block or Report'),
                ),
              ];
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child:
                _isLoadingHistory
                    ? const Center(child: CircularProgressIndicator())
                    : _messages.isEmpty
                    ? Center(
                      child: Text(
                        "No messages yet.\nStart the conversation!",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    )
                    : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        return _buildChatMessageWidget(_messages[index]);
                      },
                    ),
          ),
          _buildMessageInputArea(),
        ],
      ),
    );
  }

  Widget _buildChatMessageWidget(ChatMessage message) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            message.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!message.isMe)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: CircleAvatar(
                radius: 15,
                backgroundImage:
                    message.imageUrl.isNotEmpty
                        ? CachedNetworkImageProvider(message.imageUrl)
                        : null,
                backgroundColor: message.imageUrl.isEmpty ? Colors.grey : null,
                onBackgroundImageError:
                    message.imageUrl.isNotEmpty
                        ? (exception, stackTrace) {
                          print('Chat Avatar load error: $exception');
                        }
                        : null,
                child:
                    message.imageUrl.isEmpty
                        ? const Icon(Icons.person, size: 15)
                        : null,
              ),
            ),
          Flexible(
            child: Column(
              crossAxisAlignment:
                  message.isMe
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: 8.0,
                  ),
                  decoration: BoxDecoration(
                    color:
                        message.isMe
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Colors.grey[300],
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Text(
                    message.text,
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message.getFormattedTime(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          if (message.isMe)
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: CircleAvatar(
                radius: 15,
                backgroundColor: Colors.blue,
                child: const Text(
                  'Me',
                  style: TextStyle(fontSize: 10, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _clearChatConfirmation() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Clear Chat?'),
          content: const Text(
            'Are you sure you want to permanently delete all messages in this chat?',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text(
                'Clear Chat',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      setState(() {
        _messages.clear();
      });
      await _saveChatHistory();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Chat cleared')));
    }
  }

  Widget _buildMessageInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -1),
            blurRadius: 2,
            color: Colors.grey.withOpacity(0.1),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 120.0),
                child: TextField(
                  controller: _messageController,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    border: InputBorder.none,
                    fillColor: Colors.grey[100],
                    filled: true,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(25),
              child: InkWell(
                borderRadius: BorderRadius.circular(25),
                onTap: _sendMessage,
                child: const Padding(
                  padding: EdgeInsets.all(10.0),
                  child: Icon(Icons.send, color: Colors.white, size: 24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EditMemberDetailsScreen extends StatefulWidget {
  final Member member;
  final Function(Member) onMemberUpdated;

  const EditMemberDetailsScreen({
    super.key,
    required this.member,
    required this.onMemberUpdated,
  });

  @override
  State<EditMemberDetailsScreen> createState() =>
      _EditMemberDetailsScreenState();
}

class _EditMemberDetailsScreenState extends State<EditMemberDetailsScreen> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _companyController;
  late TextEditingController _locationController;
  late TextEditingController _alumniYearController;
  late TextEditingController _roleController;

  File? _profileImage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.member.name);
    _descriptionController = TextEditingController(
      text: widget.member.description,
    );
    _companyController = TextEditingController(text: widget.member.company);
    _locationController = TextEditingController(text: widget.member.location);
    _alumniYearController = TextEditingController(
      text: widget.member.alumniYear ?? '',
    );
    _roleController = TextEditingController(text: widget.member.role ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _companyController.dispose();
    _locationController.dispose();
    _alumniYearController.dispose();
    _roleController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    setState(() {
      if (pickedFile != null) {
        _profileImage = File(pickedFile.path);
      } else {
        print('No image selected.');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        title: const Text('Edit Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              final updatedMember = widget.member.copyWith(
                name: _nameController.text,
                description: _descriptionController.text,
                imageUrl: _profileImage?.path ?? widget.member.imageUrl,
                company: _companyController.text,
                location: _locationController.text,
                alumniYear:
                    _alumniYearController.text.isEmpty
                        ? null
                        : _alumniYearController.text,
                role:
                    _roleController.text.isEmpty ? null : _roleController.text,
              );
              widget.onMemberUpdated(updatedMember);
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundImage:
                        _profileImage != null
                            ? FileImage(_profileImage!) as ImageProvider
                            : CachedNetworkImageProvider(widget.member.imageUrl)
                                as ImageProvider,
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _companyController,
              decoration: const InputDecoration(
                labelText: 'Company',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Location',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _alumniYearController,
              decoration: const InputDecoration(
                labelText: 'Alumni Year',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _roleController,
              decoration: const InputDecoration(
                labelText: 'Role',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Profiles extends StatelessWidget {
  const Profiles({super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ProfileUpdatesScreen(memberId: '1'),
          ),
        );
      },
      child: const Text('View Profile Updates'),
    );
  }
}

class MoreOptionsBottomSheet extends StatelessWidget {
  const MoreOptionsBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Profile'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.chat),
            title: const Text('Chatbot'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ChatbotScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _name = "John Doe";
  String _email = "john.doe@example.com";
  String _bio = "Software Engineer";
  bool _isEditing = false;
  File? _profileImage;

  String _backupName = "";
  String _backupEmail = "";
  String _backupBio = "";

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _name = prefs.getString('name') ?? "John Doe";
      _email = prefs.getString('email') ?? "john.doe@example.com";
      _bio = prefs.getString('bio') ?? "Software Engineer";

      _nameController.text = _name;
      _emailController.text = _email;
      _bioController.text = _bio;
    });
  }

  void _toggleEditMode() {
    setState(() {
      if (!_isEditing) {
        _backupName = _name;
        _backupEmail = _email;
        _backupBio = _bio;
      }

      _isEditing = !_isEditing;
    });
  }

  Future<void> _saveProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('name', _nameController.text);
    await prefs.setString('email', _emailController.text);
    await prefs.setString('bio', _bioController.text);
  }

  void _saveChanges() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Save Changes?'),
          content: const Text('Do you want to save the changes you made?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _discardChanges();
              },
              child: const Text('Discard'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _name = _nameController.text;
                  _email = _emailController.text;
                  _bio = _bioController.text;
                  _isEditing = false;
                  _saveProfileData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile updated!')),
                  );
                });
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _discardChanges() {
    setState(() {
      _nameController.text = _backupName;
      _emailController.text = _backupEmail;
      _bioController.text = _backupBio;

      _name = _backupName;
      _email = _backupEmail;
      _bio = _backupBio;

      _isEditing = false;
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    setState(() {
      if (pickedFile != null) {
        _profileImage = File(pickedFile.path);
      } else {
        print('No image selected.');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.close : Icons.edit),
            onPressed: _toggleEditMode,
          ),
          if (_isEditing)
            IconButton(icon: const Icon(Icons.save), onPressed: _saveChanges),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundImage:
                        _profileImage != null
                            ? FileImage(_profileImage!) as ImageProvider
                            : const NetworkImage(
                                  'https://via.placeholder.com/150',
                                )
                                as ImageProvider,
                  ),
                  if (_isEditing)
                    InkWell(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameController,
              enabled: _isEditing,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _emailController,
              enabled: _isEditing,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _bioController,
              enabled: _isEditing,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Bio',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            if (!_isEditing)
              ElevatedButton(
                onPressed: _toggleEditMode,
                child: const Text('Edit Profile'),
              ),
          ],
        ),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout?'),
          content: const Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                // ignore: use_build_context_synchronously
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Logged out successfully!')),
                );
                Navigator.pushReplacement(
                  // ignore: use_build_context_synchronously
                  context,
                  MaterialPageRoute(builder: (context) => const HomeScreen()),
                );
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  void _referFriend(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Refer a Friend'),
          content: const Text(
            'Invite your friends and family to join our Alumni community. Share this link with them! (Simulated link: alumni.example.com/invite)',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _deleteAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Account?'),
          content: const Text(
            'Are you sure you want to delete your account? This action is irreversible.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Account deleted!')),
                );
              },
              child: const Text('Delete'),
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
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Help'),
            onTap: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text("Help"),
                    content: const Text(
                      "If you are facing any technical issues. Please let us know or please reach out to our AI chatbot to assist your issues",
                    ),
                    actions: [
                      TextButton(
                        child: const Text("OK"),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.favorite_border),
            title: const Text('Refer a friend'),
            onTap: () => _referFriend(context),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Delete Account'),
            onTap: () => _deleteAccount(context),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () => _logout(context),
          ),
          const Divider(),
        ],
      ),
    );
  }
}

class ChatbotScreen extends StatelessWidget {
  const ChatbotScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        title: const Text('AI Chatbot'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.chat_bubble, size: 80, color: Colors.blue),
                  const SizedBox(height: 20),
                  const Text(
                    'How can I help you today?',
                    style: TextStyle(fontSize: 20),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: () {
                      //Implement action
                    },
                    child: const Text('Ask a question'),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Type your message here...',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () {
                    //Implement action
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final List<Member> memberData = [
  Member(
    id: '1',
    name: "Arigala Punith Kumar",
    description: "Batch of 1985 - 1990",
    imageUrl:
        "https://images.pexels.com/photos/771742/pexels-photo-771742.jpeg?auto=compress&cs=tinysrgb&dpr=1&w=500",
    company: "ABC Corp",
    location: "New York",
  ),
  Member(
    id: '2',
    name: "Shaik Mohammad Muddassir",
    description: "B.Tech 2019, IT",
    imageUrl:
        "https://images.unsplash.com/photo-1534528741702-a0c7cae5c23c?q=80&w=1000&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxzZWFyY2h8Mnx8cGVvcGxlfGVufDB8fDB8fHww",
    company: "XYZ Ltd",
    location: "San Francisco",
  ),
  Member(
    id: '3',
    name: "Chenji Nithin Kumar",
    description: "B.Tech of 2003",
    imageUrl:
        "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQabjU4f-zH95VwVa8-kXj7X_V0QJhTkYv8PQ&usqp=CAU",
    company: "PQR Inc",
    location: "London",
  ),
  Member(
    id: '4',
    name: "Bapatla Adarsh",
    description: "B.Tech 2016, IT",
    imageUrl:
        "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQ003r1-7-vW4g74W-sXpL-r-w1k78d0w7n3g&usqp=CAU",
    company: "ABC Corp",
    location: "New York",
  ),
  Member(
    id: '5',
    name: "Chambeti Navatej",
    description: "BTech of 1986",
    imageUrl:
        "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSNc2wO0Fm-p85tX5wtE_224iUuJQ_Qp-iHNA&usqp=CAU",
    company: "XYZ Ltd",
    location: "San Francisco",
  ),
  Member(
    id: '6',
    name: "Gurrala Prabhas",
    description: "MBA 2010",
    imageUrl:
        "https://images.unsplash.com/photo-143761681033-6461ffad8d80?q=80&w=1000&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxzZWFyY2h8M3x8cGVvcGxlfGVufDB8fDB8fHww",
    company: "PQR Inc",
    location: "London",
  ),
  Member(
    id: '7',
    name: "Baddipudi Williams",
    description: "BSc Computer Science 2005",
    imageUrl:
        "https://images.unsplash.com/photo-1500648767791-00d5a4ee9baa?q=80&w=1000&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxzZWFyY2h8OHx8cGVvcGxlfGVufDB8fDB8fHww",
    company: "ABC Corp",
    location: "New York",
  ),
  Member(
    id: '8',
    name: "Bokka Uday Akshith",
    description: "MA English Literature 2012",
    imageUrl:
        "https://images.unsplash.com/photo-1494790108377-be9c29b8c215?q=80&w=1000&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxzZWFyY2h8MTB8fHHBlZXxlbnwwfHwwfHx8MA",
    company: "XYZ Ltd",
    location: "San Francisco",
  ),
];
