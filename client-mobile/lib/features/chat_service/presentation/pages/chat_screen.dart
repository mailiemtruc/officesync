import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_frame.dart';

import '../../data/models/chat_message.dart';
import '../../data/chat_api.dart'; // Import file API vừa tạo
import 'package:officesync/features/chat_service/widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatApi _chatApi = ChatApi(); // Khởi tạo API
  StompClient? stompClient;

  List<ChatMessage> messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final String myId = "1";
  final String partnerId = "2";

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _connectWebSocket();
  }

  // Dùng _chatApi để lấy dữ liệu
  void _loadHistory() async {
    final history = await _chatApi.fetchHistory(myId, partnerId);
    setState(() {
      messages = history;
    });
    _scrollToBottom();
  }

  void _connectWebSocket() {
    stompClient = StompClient(
      config: StompConfig(
        url: ChatApi.wsUrl, // Lấy URL từ file ChatApi
        onConnect: (StompFrame frame) {
          stompClient!.subscribe(
            destination: '/topic/user/$myId',
            callback: (StompFrame frame) {
              if (frame.body != null) {
                final jsonMap = json.decode(frame.body!);
                setState(() {
                  messages.add(ChatMessage.fromJson(jsonMap));
                });
                _scrollToBottom();
              }
            },
          );
        },
      ),
    );
    stompClient!.activate();
  }

  void _sendMessage() {
    if (_controller.text.isEmpty) return;

    stompClient!.send(
      destination: '/app/chat.sendMessage',
      body: json.encode({
        'sender': myId,
        'content': _controller.text,
        'type': 'CHAT',
      }),
    );
    _controller.clear();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      });
    }
  }

  @override
  void dispose() {
    stompClient?.deactivate();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Chat với User $partnerId")),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                return MessageBubble(message: msg, isMe: msg.sender == myId);
              },
            ),
          ),
          // Khu vực nhập tin nhắn (Giữ nguyên code cũ hoặc tách widget tùy bạn)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(child: TextField(controller: _controller)),
                IconButton(icon: Icon(Icons.send), onPressed: _sendMessage),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
