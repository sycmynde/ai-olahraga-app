import 'dart0:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fllama/fllama.dart';

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
  
  String selectedModel = 'Qwen2.5 0.5B';
  String? localModelPath;
  bool isDownloading = false;
  double downloadProgress = 0.0;
  bool isModelReady = false;

  final Map<String, String> modelUrls = {
    'Qwen2.5 0.5B': 'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf',
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
    if (file.existsSync()) {
      setState(() {
        isModelReady = true;
        localModelPath = filePath;
      });
    }
  }

  Future<void> _pickLocalModel() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );

    if (result != null && result.files.single.path != null) {
      String path = result.files.single.path!;
      if (path.endsWith('.gguf')) {
        setState(() {
          localModelPath = path;
          isModelReady = true;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Model Terpilih: ${result.files.single.name}')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pilih file berformat .gguf!')),
          );
        }
      }
    }
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
        localModelPath = filePath;
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

  void _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;
    if (localModelPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih file model .gguf dulu bro!')),
      );
      return;
    }

    final userText = _controller.text;
    setState(() {
      _messages.add(Message(sender: 'user', text: userText));
      _controller.clear();
      _messages.add(Message(sender: 'ai', text: 'Sedang berpikir... 🧠'));
    });

    try {
      final req = OpenAiRequest(
        modelPath: localModelPath!,
        messages: [
          MessageOpenAi(
            role: "system",
            content: "Kamu adalah teman olahraga yang asik, ramah, dan memotivasi. Jawab singkat dan santai.",
          ),
          MessageOpenAi(
            role: "user",
            content: userText,
          ),
        ],
        contextSize: 2048,
      );

      String aiResponse = "";
      
      await fllamaInference(req, (response, done) {
        aiResponse += response.toString();
        setState(() {
          _messages[_messages.length - 1] = Message(sender: 'ai', text: aiResponse);
        });
      });
    } catch (e) {
      setState(() {
        _messages[_messages.length - 1] = Message(
          sender: 'ai',
          text: 'Gagal memproses AI: $e',
        );
      });
    }
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
          Card(
            margin: const EdgeInsets.all(8.0),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          isModelReady ? 'Model: ${localModelPath?.split('/').last}' : selectedModel,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isModelReady)
                        const Chip(label: Text('Siap'), backgroundColor: Colors.greenAccent)
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickLocalModel,
                          icon: const Icon(Icons.folder_open),
                          label: const Text('Pilih File HP'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: isDownloading ? null : _downloadModel,
                          icon: const Icon(Icons.download),
                          label: const Text('Download'),
                        ),
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