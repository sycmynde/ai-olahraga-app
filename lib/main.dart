import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Temen Olahraga++',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: const ChatScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class Message {
  final String sender;
  final String text;
  Message({required this.sender, required this.text});
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Message> _messages = [];
  
  String selectedModel = 'Qwen2.5 0.5B (390MB)';
  bool isDownloading = false;
  double downloadProgress = 0.0;
  bool isModelReady = false;

  final Map<String, String> modelUrls = {
    'Qwen2.5 0.5B (390MB)': 'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf',
  };

  @override
  void initState() {
    super.initState();
    _checkModelExistence();
  }

  Future<void> _checkModelExistence() async {
    final dir = await getApplicationDocumentsDirectory();
    final filePath = '${dir.path}/model.gguf';
    final file = File(filePath);
    setState(() {
      isModelReady = file.existsSync();
    });
  }

  Future<void> _downloadModel() async {
    setState(() {
      isDownloading = true;
      downloadProgress = 0.0;
    });

    try {
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/model.gguf';
      final url = modelUrls[selectedModel]!;

      Dio dio = Dio();
      await dio.download(url, filePath, onReceiveProgress: (received, total) {
        if (total != -1) {
          setState(() {
            downloadProgress = received / total;
          });
        }
      });

      setState(() {
        isDownloading = false;
        isModelReady = true;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Model AI Berhasil Diunduh!')),
        );
      }
    } catch (e) {
      setState(() {
        isDownloading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal unduh model: $e')),
        );
      }
    }
  }

  void _sendMessage() {
    if (_controller.text.trim().isEmpty) return;

    final userText = _controller.text;
    setState(() {
      _messages.add(Message(sender: 'user', text: userText));
      _controller.clear();
    });

    // Respon sementara sebelum disambungkan dengan engine inference C++
    Future.delayed(const Duration(milliseconds: 600), () {
      setState(() {
        _messages.add(Message(
          sender: 'ai',
          text: 'Halo bro! Aku temen olahragamu. Kamu nanya: "$userText". Tetap semangat workout hari ini! 🔥',
        ));
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Temen Olahraga++'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // Card Status & Downloader Model
          Card(
            margin: const EdgeInsets.all(8.0),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(selectedModel, style: const TextStyle(fontWeight: FontWeight.bold)),
                      isModelReady
                          ? const Chip(label: Text('Siap Dipakai'), backgroundColor: Colors.greenAccent)
                          : ElevatedButton(
                              onPressed: isDownloading ? null : _downloadModel,
                              child: const Text('Download Model'),
                            ),
                    ],
                  ),
                  if (isDownloading) ...[
                    const SizedBox(height: 10),
                    LinearProgressIndicator(value: downloadProgress),
                    const SizedBox(height: 4),
                    Text('${(downloadProgress * 100).toStringAsFixed(1)}%'),
                  ]
                ],
              ),
            ),
          ),

          // Area Tampilan Chat
          Expanded(
            child: _messages.isEmpty
                ? const Center(child: Text('Belum ada percakapan. Mulai sapa teman workout-mu!'))
                : ListView.builder(
                    padding: const EdgeInsets.all(8.0),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isUser = msg.sender == 'user';
                      return Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4.0),
                          padding: const EdgeInsets.all(12.0),
                          decoration: BoxDecoration(
                            color: isUser ? Colors.deepOrange[100] : Colors.grey[300],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(msg.text, style: const TextStyle(fontSize: 16)),
                        ),
                      );
                    },
                  ),
          ),

          // Input Pesan
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Tanyakan sesuatu tentang olahraga...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.deepOrange),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
