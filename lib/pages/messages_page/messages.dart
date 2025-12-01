import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:polygone_app/pages/const/navigatorbar.dart';
import 'widget/appbar.dart';

class Messages extends StatefulWidget {
  const Messages({super.key});

  @override
  State<Messages> createState() => _MessagesState();
}

class _MessagesState extends State<Messages> {
  List<Message_t> messages = [
    Message_t(id: 1, name: "Alice", message: "Hello!", time: "10:00 AM" , nbrNewMessages: 2, isOnline: true),
    Message_t(id: 2, name: "Bob", message: "How are you?", time: "10:05 AM" , nbrNewMessages: 1, isTyping: true),
    Message_t(id: 3, name: "Charlie", message: "Let's meet up.", time: "10:10 AM" , nbrNewMessages: 0 , isOnline: false),
    Message_t(id: 4, name: "Diana", message: "See you soon!", time: "10:15 AM" , nbrNewMessages: 3, isOnline: true),
    Message_t(id: 5, name: "Eve", message: "Goodbye!", time: "10:20 AM" , nbrNewMessages: 0 , isOnline: false),
    Message_t(id: 6, name: "Rest", message: "Taking a break", time: "10:25 AM" , nbrNewMessages: 0 , isOnline: false),
    Message_t(id: 7, name: "Alice", message: "Hello!", time: "10:00 AM" , nbrNewMessages: 2, isOnline: true),
    Message_t(id: 8, name: "Bob", message: "How are you?", time: "10:05 AM" , nbrNewMessages: 1, isTyping: true),
    Message_t(id: 9, name: "Charlie", message: "Let's meet up.", time: "10:10 AM" , nbrNewMessages: 0 , isOnline: false),
    Message_t(id: 10, name: "Diana", message: "See you soon!", time: "10:15 AM" , nbrNewMessages: 3, isOnline: true),
    Message_t(id: 11, name: "Eve", message: "Goodbye!", time: "10:20 AM" , nbrNewMessages: 0 , isOnline: false),
    Message_t(id: 12, name: "Rest", message: "Taking a break", time: "10:25 AM" , nbrNewMessages: 0 , isOnline: false),
    Message_t(id: 13, name: "Alice", message: "Hello!", time: "10:00 AM" , nbrNewMessages: 2, isOnline: true),
    Message_t(id: 14, name: "Bob", message: "How are you?", time: "10:05 AM" , nbrNewMessages: 1, isTyping: true),
    Message_t(id: 15, name: "Charlie", message: "Let's meet up.", time: "10:10 AM" , nbrNewMessages: 0 , isOnline: false),
    Message_t(id: 16, name: "Diana", message: "See you soon!", time: "10:15 AM" , nbrNewMessages: 3, isOnline: true),
    Message_t(id: 17, name: "Eve", message: "Goodbye!", time: "10:20 AM" , nbrNewMessages: 0 , isOnline: false),
    Message_t(id: 18, name: "Rest", message: "Taking a break", time: "10:25 AM" , nbrNewMessages: 0 , isOnline: false),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: MessagesAppBar(),
      ),
      bottomNavigationBar: NavigatorbarLine(),
      floatingActionButton: CircleAvatar(
        radius: 28,
        backgroundColor: Colors.teal,
        child: IconButton(
        onPressed: (){

        },
        icon: Icon(
          LucideIcons.messageCircle,
          color: Colors.white,
          size: 32,
          )
      ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ListView.separated(
          itemCount: messages.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final m = messages[index];
              return Card(
                child: ListTile(
                  onTap: () {
                    // Navigate to message detail page
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => Messages(),
                      ),
                    );
                  },
                leading: SizedBox(
                    width: 48,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircleAvatar(
                          backgroundImage: AssetImage(m.avatarImagePath),
                        ),
                        if (m.isOnline)
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  title: Text(m.name , style: const TextStyle(fontFamily: 'Roboto',fontWeight: FontWeight.w700),),
                  subtitle: Text(m.message, style: TextStyle(fontFamily: 'Roboto-Thin',fontWeight: m.nbrNewMessages>0 ?  FontWeight.w400 : FontWeight.w100),),
                  trailing: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(m.time, style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                      SizedBox(height: 4),
                      m.nbrNewMessages > 0 ?  CircleAvatar(
                        radius: 10,
                        backgroundColor: Colors.teal,
                        child: m.nbrNewMessages > 0 ? Text('${m.nbrNewMessages}' , style: const TextStyle(fontSize: 12 , fontFamily: 'Roboto'),) : null,
                      ) : const SizedBox.shrink(),
                    ],
                  ),
                ),
                
              );
            },
          ),
        ),
      );
  }
}

class Message_t{
  int id ;
  String name;
  String message;
  String time;
  String avatarImagePath;
  int nbrNewMessages;
  bool isOnline;
  bool isTyping;
  Message_t({
    required this.id,
    required this.name,
    required this.message,
    required this.time,
    this.avatarImagePath = '',
    this.nbrNewMessages = 0,
    this.isOnline = false,
    this.isTyping = false,
  });
}