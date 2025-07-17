import 'package:flutter/material.dart';
import '../widgets/song_card.dart';
import 'song_detail_page.dart';
import '../models/song.dart';

class SearchPage extends StatefulWidget {
  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();

  // 예시 곡 데이터
  final List<Map<String, String>> songs = [
    {
      'title': 'Never Ending Story',
      'artist': 'IU',
      'image': 'assets/images/iu.webp',
    },
    {
      'title': 'Drowning',
      'artist': 'WOODZ',
      'image': 'assets/images/no_pain.webp',
    },
    {
      'title': 'FAMOUS',
      'artist': 'Allday Project',
      'image': 'assets/images/famous.webp',
    },
    {
      'title': 'NO PAIN',
      'artist': '실리카겔',
      'image': 'assets/images/no_pain.webp',
    },
    {'title': 'Celebrity', 'artist': 'IU', 'image': 'assets/images/iu.webp'},
    {'title': 'Blueming', 'artist': 'IU', 'image': 'assets/images/iu.webp'},
  ];

  List<Map<String, String>> get filteredSongs {
    if (_searchController.text.isEmpty) return songs;

    return songs.where((song) {
      final query = _searchController.text.toLowerCase();
      return song['title']!.toLowerCase().contains(query) ||
          song['artist']!.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // 검색바
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {});
                },
                decoration: InputDecoration(
                  hintText: '노래, 아티스트 검색',
                  hintStyle: TextStyle(color: Colors.grey[500], fontSize: 16),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.grey[600],
                    size: 20,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),

          // 검색 결과 또는 추천 곡
          Expanded(
            child: _searchController.text.isNotEmpty
                ? _buildSearchResults()
                : _buildRecommendations(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    final results = filteredSongs;

    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              '검색 결과가 없습니다',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '다른 키워드로 검색해보세요',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 20),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final songData = results[index];
        // 상세 페이지로 전달할 Song 객체 생성
        final song = Song(
          title: songData['title']!,
          artist: songData['artist']!,
          albumCover: songData['image']!,
          difficulty: '중급', // 임시 데이터
          range: 'C4-G5', // 임시 데이터
          lyrics: '가사 정보가 없습니다.', // 임시 데이터
          duration: '3:30', // 임시 데이터
        );

        return InkWell(
          onTap: () {
            // 클릭 시 SongDetailPage로 이동
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SongDetailPage(song: song),
              ),
            );
          },
          child: Container(
            margin: EdgeInsets.only(bottom: 16),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    song.albumCover, // Song 객체의 albumCover 사용
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title, // Song 객체의 title 사용
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        song.artist, // Song 객체의 artist 사용
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded, // 오른쪽 화살표 아이콘으로 변경
                  color: Colors.grey[400],
                  size: 24,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecommendations() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            '인기 검색어',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
        SizedBox(height: 12),
        Container(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 20),
            itemCount: ['IU', 'BTS', 'NewJeans', 'LE SSERAFIM'].length,
            itemBuilder: (context, index) {
              final keyword = ['IU', 'BTS', 'NewJeans', 'LE SSERAFIM'][index];
              return GestureDetector(
                onTap: () {
                  _searchController.text = keyword;
                  setState(() {});
                },
                child: Container(
                  margin: EdgeInsets.only(right: 12),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    keyword,
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(height: 24),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            '추천 곡',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
        SizedBox(height: 12),
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.symmetric(horizontal: 20),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.75, // SongCard(정사각형+텍스트+padding) 비율에 맞게 조정
              crossAxisSpacing: 12,
              mainAxisSpacing: 16,
            ),
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final songData = songs[index];
              final song = Song(
                title: songData['title']!,
                artist: songData['artist']!,
                albumCover: songData['image']!,
                difficulty: '초급', // 임시 값
                range: 'C4 ~ C5', // 임시 값
                lyrics: '가사 없음', // 임시 값
                duration: '0:00', // 임시 값
              );
              return SongCard(song: song);
            },
          ),
        ),
      ],
    );
  }
}
