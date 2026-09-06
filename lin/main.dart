import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'n8n Command Center',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    N8nControlScreen(),
    AiChatScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.flash_on),
            label: 'n8n Pulti',
          ),
          NavigationDestination(
            icon: Icon(Icons.psychology),
            label: 'AI Yordamchi',
          ),
        ],
      ),
    );
  }
}

// --- N8N CONTROL SCREEN ---
class N8nControlScreen extends StatefulWidget {
  const N8nControlScreen({super.key});

  @override
  State<N8nControlScreen> createState() => _N8nControlScreenState();
}

class _N8nControlScreenState extends State<N8nControlScreen> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _promptController = TextEditingController();
  String _output = 'Natija bu yerda ko\'rinadi...';
  bool _isLoading = false;

  Future<void> _sendWebhook() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Iltimos, Webhook URL manzilini kiriting')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _output = 'Yuborilmoqda va n8n kutilmoqda...';
    });

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'prompt': _promptController.text.trim(),
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      setState(() {
        _output = 'Status: ${response.statusCode}\n\nJavob:\n${response.body}';
      });
    } catch (e) {
      setState(() {
        _output = 'Xatolik yuz berdi: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _shareToTelegram() {
    if (_output.isNotEmpty) {
      Share.share(_output);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('n8n Command Center')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'n8n Webhook URL',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _promptController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Prompt / Ma\'lumot kiritish',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.edit),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _sendWebhook,
              icon: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send),
              label: Text(_isLoading ? 'Ishlanmoqda...' : 'n8n ga Yuborish'),
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Natija:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: _shareToTelegram,
                  tooltip: 'Ulashish',
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[800]!),
              ),
              child: SelectableText(_output, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}

// --- AI CHAT SCREEN ---
class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _chatController = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isChatLoading = false;

  Future<void> _sendMessage() async {
    final apiKey = _apiKeyController.text.trim();
    final prompt = _chatController.text.trim();

    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gemini API Key-ni kiriting')),
      );
      return;
    }
    if (prompt.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'text': prompt});
      _isChatLoading = true;
    });
    _chatController.clear();

    try {
      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);
      final response = await model.generateContent([Content.text(prompt)]);

      setState(() {
        _messages.add({'role': 'ai', 'text': response.text ?? 'Javob olina olmadi.'});
      });
    } catch (e) {
      setState(() {
        _messages.add({'role': 'ai', 'text': 'Xatolik: $e'});
      });
    } finally {
      setState(() {
        _isChatLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Copilot (Gemini)')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _apiKeyController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Gemini API Key',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.key),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.deepPurple : Colors.grey[800],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SelectableText(msg['text'] ?? ''),
                  ),
                );
              },
            ),
          ),
          if (_isChatLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    decoration: const InputDecoration(
                      hintText: 'Savol yoki topshiriq yozing...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _isChatLoading ? null : _sendMessage,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
