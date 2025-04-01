import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io'; // Import for File type

// Define the Member class (unchanged)
class Member {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final String company;
  final String location;

  Member({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.company,
    required this.location,
  });
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _name = "John Doe"; // Default name
  String _email = "john.doe@example.com"; // Default email
  String _bio = "Software Engineer"; // Default bio
  bool _isEditing = false;

  String _backupName = "";
  String _backupEmail = "";
  String _backupBio = "";

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  // For profile picture
  File? _profileImage;
  String _profileImageUrl =
      'https://via.placeholder.com/150'; //Default image URL
  String _backupProfileImageUrl =
      'https://via.placeholder.com/150'; // Backup Image URL

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
      _profileImageUrl =
          prefs.getString('profileImage') ?? 'https://via.placeholder.com/150';

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
        _backupProfileImageUrl = _profileImageUrl; // Backup Profile Image
      }
      _isEditing = !_isEditing;
    });
  }

  Future<void> _saveProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('name', _nameController.text);
    await prefs.setString('email', _emailController.text);
    await prefs.setString('bio', _bioController.text);
    await prefs.setString('profileImage', _profileImageUrl); // Save image URL
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
              child: const Text(
                'Discard',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Theme.of(context).colorScheme.onSecondary,
              ),
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _name = _nameController.text;
                  _email = _emailController.text;
                  _bio = _bioController.text;
                  _profileImageUrl = _profileImageUrl; // Save profile Image
                  _isEditing = false;
                  _saveProfileData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile updated!')),
                  );
                });
              },
              child: const Text('Yes'),
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
      _profileImageUrl = _backupProfileImageUrl;

      _name = _backupName;
      _email = _backupEmail;
      _bio = _backupBio;
      _profileImageUrl = _backupProfileImageUrl;

      _isEditing = false;
    });
  }

  // Image picker function
  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );

    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
        _profileImageUrl = pickedFile.path; //Use the path directly
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final fontSize = screenWidth * 0.04;
    final isSmallScreen = screenWidth < 600;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        title: const Text('Profile'),
      ),
      backgroundColor: Colors.grey[50], // Light background
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isSmallScreen ? double.infinity : 600,
              ), //Responsive width
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Profile Picture and Edit Icon
                  Align(
                    alignment: Alignment.center,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        SizedBox(
                          width: 100,
                          height: 100,
                          child: InkWell(
                            onTap: _isEditing ? _pickImage : null,
                            child: CircleAvatar(
                              radius: 50,
                              backgroundImage:
                                  _profileImage !=
                                          null //Conditional Image
                                      ? FileImage(_profileImage!)
                                      : NetworkImage(_profileImageUrl)
                                          as ImageProvider, // Type cast as ImageProvider
                              backgroundColor:
                                  Colors.white, // Added background color
                            ),
                          ),
                        ),
                        if (!_isEditing)
                          InkWell(
                            onTap: _toggleEditMode,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.secondary,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.edit,
                                color:
                                    Theme.of(context).colorScheme.onSecondary,
                                size: 20,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Name Field
                  TextFormField(
                    controller: _nameController,
                    enabled: _isEditing,
                    style: TextStyle(fontSize: fontSize),
                    decoration: InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      labelStyle: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    enabled: _isEditing,
                    style: TextStyle(fontSize: fontSize),
                    decoration: InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      labelStyle: TextStyle(color: Colors.grey[600]),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),

                  // Bio Field
                  TextFormField(
                    controller: _bioController,
                    enabled: _isEditing,
                    style: TextStyle(fontSize: fontSize),
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Bio',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      labelStyle: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Save Button (Conditional)
                  if (_isEditing)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.secondary,
                        foregroundColor:
                            Theme.of(context).colorScheme.onSecondary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(fontSize: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _saveChanges,
                      child: const Text('Save'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  ThemeMode _themeMode = ThemeMode.system; // Default theme mode

  bool _showNotifications = true; // Default notification setting
  bool _darkChatTheme = false; // Default dark chat theme

  //Profile data
  String _name = "John Doe";
  String _email = "john.doe@example.com";
  String _profileImageUrl = 'https://via.placeholder.com/150';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadProfileData();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _themeMode =
          ThemeMode.values[prefs.getInt('themeMode') ?? ThemeMode.system.index];
      _showNotifications = prefs.getBool('notifications') ?? true;
      _darkChatTheme = prefs.getBool('darkChatTheme') ?? false;
    });
  }

  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _name = prefs.getString('name') ?? "John Doe";
      _email = prefs.getString('email') ?? "john.doe@example.com";
      _profileImageUrl =
          prefs.getString('profileImage') ?? 'https://via.placeholder.com/150';
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', _themeMode.index);
    await prefs.setBool('notifications', _showNotifications);
    await prefs.setBool('darkChatTheme', _darkChatTheme);

    // Trigger theme change by rebuilding the app
    (context as Element).markNeedsBuild();
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
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK', style: TextStyle(color: Colors.grey)),
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
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
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

  void _logout(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout?'),
          content: const Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Logged out successfully!')),
                );
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final fontSize = screenWidth * 0.04;
    final isSmallScreen = screenWidth < 600;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        title: const Text('Settings'),
        centerTitle: true,
      ),
      backgroundColor: Colors.grey[50],
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isSmallScreen ? double.infinity : 600,
            ), //Responsive width
            child: Column(
              children: [
                //Profile Section
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ProfileScreen(),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.white,
                          backgroundImage: NetworkImage(_profileImageUrl),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            _name, // Use the loaded name
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ProfileScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const Divider(height: 1, thickness: 1),
                // Display Settings
                ListTile(
                  leading: const Icon(Icons.brightness_6, color: Colors.purple),
                  title: Text('Display', style: TextStyle(fontSize: fontSize)),
                  trailing: DropdownButton<ThemeMode>(
                    value: _themeMode,
                    items: const [
                      DropdownMenuItem(
                        value: ThemeMode.system,
                        child: Text('System Default'),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.light,
                        child: Text('Light'),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.dark,
                        child: Text('Dark'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _themeMode = value!;
                      });
                      _saveSettings();
                    },
                  ),
                ),
                const Divider(height: 1, thickness: 1),

                // Chat Settings
                ListTile(
                  leading: const Icon(Icons.chat, color: Colors.blueGrey),
                  title: Text('Chat', style: TextStyle(fontSize: fontSize)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text("Notifications:"),
                          Switch(
                            value: _showNotifications,
                            onChanged: (value) {
                              setState(() {
                                _showNotifications = value;
                              });
                              _saveSettings();
                            },
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Text("Dark Chat Theme:"),
                          Switch(
                            value: _darkChatTheme,
                            onChanged: (value) {
                              setState(() {
                                _darkChatTheme = value;
                              });
                              _saveSettings();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 1),
                //Help Section
                ListTile(
                  leading: const Icon(Icons.help_outline, color: Colors.blue),
                  title: Text('Help', style: TextStyle(fontSize: fontSize)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text("Help"),
                          content: const Text(
                            "If you are facing any technical issues. Please let us know or please reach out to our AI chatbot to assist your issues ",
                          ),
                          actions: [
                            TextButton(
                              child: const Text(
                                "OK",
                                style: TextStyle(color: Colors.grey),
                              ),
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
                const Divider(height: 1, thickness: 1),
                //Refer a friend
                ListTile(
                  leading: const Icon(
                    Icons.favorite_border,
                    color: Colors.green,
                  ),
                  title: Text(
                    'Refer a friend',
                    style: TextStyle(fontSize: fontSize),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    _referFriend(context);
                  },
                ),
                const Divider(height: 1, thickness: 1),
                //Delete account
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: Text(
                    'Delete Account',
                    style: TextStyle(fontSize: fontSize),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    _deleteAccount(context);
                  },
                ),
                const Divider(height: 1, thickness: 1),
                //Logout
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.orange),
                  title: Text('Logout', style: TextStyle(fontSize: fontSize)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    _logout(context);
                  },
                ),
                const Divider(height: 1, thickness: 1),
              ],
            ),
          ),
        ),
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
      body: Container(
        color: Colors.blue[50],
        child: const Center(child: Text('Chatbot functionality coming soon!')),
      ),
    );
  }
}

// Wrapper to apply ThemeMode based on settings
class ThemeWrapper extends StatefulWidget {
  final Widget child;

  const ThemeWrapper({super.key, required this.child});

  @override
  State<ThemeWrapper> createState() => _ThemeWrapperState();
}

class _ThemeWrapperState extends State<ThemeWrapper> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _themeMode =
          ThemeMode.values[prefs.getInt('themeMode') ?? ThemeMode.system.index];
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: _themeMode,
      home: widget.child,
    );
  }
}
