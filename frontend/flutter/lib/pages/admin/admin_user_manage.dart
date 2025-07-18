import 'package:flutter/material.dart';

import '../login_page.dart';

class User {
  final String name;
  final String level;
  User(this.name, this.level);
}

class AdminUserManage extends StatefulWidget {
  @override
  _AdminUserManageState createState() => _AdminUserManageState();
}

class _AdminUserManageState extends State<AdminUserManage> {
  List<User> users = [User('사용자1', 'A'), User('사용자2', 'B'), User('사용자3', 'C')];

  List<User> displayedUsers = [];

  @override
  void initState() {
    super.initState();
    displayedUsers = List.from(users);
  }

  void _searchUser() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        String input = '';
        return AlertDialog(
          title: const Text('회원 이름 검색'),
          content: TextField(
            onChanged: (value) => input = value,
            decoration: const InputDecoration(hintText: '이름을 입력하세요'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, input),
              child: const Text('검색'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        displayedUsers = users
            .where((user) => user.name.contains(result))
            .toList();
      });
    } else {
      setState(() {
        displayedUsers = List.from(users);
      });
    }
  }

  void _resetSearch() {
    setState(() {
      displayedUsers = List.from(users);
    });
  }

  void _editUser(User user) {
    // TODO: 회원 수정 로직 추가
    print('수정: ${user.name}');
  }

  void _deleteUser(User user) {
    setState(() {
      users.remove(user);
      displayedUsers.remove(user);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('회원 관리 페이지')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: displayedUsers.length,
                itemBuilder: (context, index) {
                  final user = displayedUsers[index];
                  return ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(user.name),
                    subtitle: Text('회원 등급: ${user.level}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () => _editUser(user),
                          child: const Text('수정'),
                        ),
                        TextButton(
                          onPressed: () => _deleteUser(user),
                          child: const Text('탈퇴'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _searchUser,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: const Text('회원 검색'),
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
