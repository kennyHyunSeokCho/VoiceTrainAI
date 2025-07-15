import 'package:flutter/material.dart';

import '../login_page.dart';
import 'admin_user_manage.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final TextEditingController _emailController = TextEditingController();
  final List<Map<String, String>> _admins = [
    {'name': '관리자1', 'email': 'admin1@example.com'},
    {'name': '관리자2', 'email': 'admin2@example.com'},
  ];

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _addAdmin() {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    setState(() {
      _admins.add({'name': email.split('@').first, 'email': email});
      _emailController.clear();
    });
  }

  void _removeAdmin(int index) {
    setState(() {
      _admins.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('관리자 페이지'),
        actions: const [
          Icon(Icons.vpn_key), // 열쇠 아이콘
          SizedBox(width: 12),
          Icon(Icons.account_circle), // 사용자 아이콘
          SizedBox(width: 16),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 상단 버튼
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => AdminUserManage(),
                      ),
                      (route) => false,
                    );
                  },
                  icon: const Icon(Icons.person),
                  label: const Text('회원 관리'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    // TODO : 노래 관리(추가) 페이지 연결
                  },
                  icon: const Icon(Icons.music_note),
                  label: const Text('노래 관리'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // 관리자 추가
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: '이메일 입력',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(onPressed: _addAdmin, child: const Text('추가')),
              ],
            ),
            const SizedBox(height: 24),
            // 관리자 목록
            Expanded(
              child: ListView.separated(
                itemCount: _admins.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, i) {
                  final admin = _admins[i];
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(admin['name']!),
                    subtitle: Text('이메일: ${admin['email']}'),
                    trailing: TextButton.icon(
                      onPressed: () => _removeAdmin(i),
                      label: const Text(
                        '삭제',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  );
                },
              ),
            ),
            // 하단 버튼
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // TODO : 뭘 설정하는지?
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: const Text('설정'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // TODO : 로그아웃 로직
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => LoginPage(),
                        ), // 로그아웃 시 로그인 페이지로 이동
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black, // 배경색
                      foregroundColor: Colors.white, // 글자색
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: const Text('로그아웃'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
