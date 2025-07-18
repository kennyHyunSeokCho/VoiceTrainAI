import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../login_page.dart';

class AdminSongManage extends StatefulWidget {
  @override
  _AdminSongManageState createState() => _AdminSongManageState();
}

class _AdminSongManageState extends State<AdminSongManage> {
  final _titleController = TextEditingController();
  final _artistController = TextEditingController();
  final _lyricsController = TextEditingController();
  XFile? _albumImage;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _albumImage = picked);
    }
  }

  void _onSubmit() {
    // TODO: 등록 로직
    print('제목: ${_titleController.text}');
    print('가수: ${_artistController.text}');
    print('가사: ${_lyricsController.text}');
  }

  void _logout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('노래 관리 페이지'),
        actions: const [
          Icon(Icons.vpn_key),
          SizedBox(width: 16),
          Icon(Icons.notifications),
          SizedBox(width: 16),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: ListView(
          children: [
            // 상단 버튼 2개
            Row(
              children: [
                Expanded(child: _menuButton(Icons.person, '회원 관리')),
                SizedBox(width: 16),
                Expanded(
                  child: _menuButton(Icons.admin_panel_settings, '관리자 설정'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            const Text(
              '노래 추가',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Text(
              '(이미지 형식은 PNG, WEBP, JFIF)',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // 앨범 이미지 업로드
            GestureDetector(
              onTap: _pickImage,
              child: _albumImage == null
                  ? Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.add_a_photo,
                        size: 40,
                        color: Colors.grey,
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(_albumImage!.path),
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            const Text('노래 정보를 추가해주세요.', style: TextStyle(color: Colors.grey)),

            const SizedBox(height: 12),
            _inputField(_titleController, '노래 제목 입력 (검색하면 크롤링해서 가져올 수 있게)'),
            const SizedBox(height: 12),
            _inputField(_artistController, '노래 가수 입력'),
            const SizedBox(height: 12),
            _inputField(_lyricsController, '노래 가사 입력'),

            const SizedBox(height: 24),

            // 버튼 2개
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _onSubmit,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('설정'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _logout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
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

  Widget _menuButton(IconData icon, String label) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [Icon(icon, size: 32), SizedBox(height: 4), Text(label)],
      ),
    );
  }

  Widget _inputField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}
