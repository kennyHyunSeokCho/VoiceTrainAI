import 'dart:async';
import 'package:flutter/material.dart';

/// 검색 결과 모델
class SearchResult {
  final String songTitle;
  final String singer;
  final String nickname;
  final String count;
  final String albumImageUrl;

  SearchResult({
    required this.songTitle,
    required this.singer,
    required this.nickname,
    required this.count,
    required this.albumImageUrl,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      songTitle: json['song_title'] as String? ?? '',
      singer: json['singer'] as String? ?? '',
      nickname: json['nickname'] as String? ?? '',
      count: json['count'] as String? ?? '0',
      albumImageUrl: json['album_image_url'] as String? ?? '',
    );
  }
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  // 0=노래명,1=가수명,2=유저명
  int _selectedFilter = 0;
  final _filterLabels = ['노래명', '가수명', '유저명'];

  final List<SearchResult> _allResults = List.generate(
    20,
    (i) => SearchResult(
      songTitle: i.isEven ? 'Never Ending Story' : '미인',
      singer: i.isEven ? 'IU' : '신용재',
      nickname: i % 3 == 0 ? 'Alice' : 'Bob',
      count: '${i + 3}k',
      albumImageUrl: i.isEven ? 'https://via.placeholder.com/50' : '',
    ),
  );

  // 추천 검색어 목록
  final List<String> _suggestions = [
    'Never Ending Story',
    '미인',
    'Drowning',
    'IU',
    'WOODZ',
  ];

  // 검색 결과 필터링
  List<SearchResult> get _filteredResults {
    final q = _controller.text.trim();
    final isHangul = RegExp(r'[ㄱ-ㅎㅏ-ㅣ가-힣]').hasMatch(q);

    return _allResults.where((r) {
      if (isHangul) {
        return r.songTitle.contains(q) ||
            r.singer.contains(q) ||
            r.nickname.contains(q);
      }
      switch (_selectedFilter) {
        case 0:
          return r.songTitle.toLowerCase().contains(q.toLowerCase());
        case 1:
          return r.singer.toLowerCase().contains(q.toLowerCase());
        case 2:
          return r.nickname.toLowerCase().contains(q.toLowerCase());
        default:
          return false;
      }
    }).toList();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => setState(() {}));
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onSearchChanged);
    _controller.dispose();
    super.dispose();
  }

  Widget _buildFilterTabs() {
    return Row(
      children: [
        for (var i = 0; i < _filterLabels.length; i++)
          GestureDetector(
            onTap: () => setState(() => _selectedFilter = i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    width: 2,
                    color: _selectedFilter == i
                        ? Color(0xff8917E3)
                        : Colors.transparent,
                  ),
                ),
              ),
              child: Text(
                _filterLabels[i],
                style: TextStyle(
                  fontWeight: _selectedFilter == i
                      ? FontWeight.w600
                      : FontWeight.w400,
                  color: _selectedFilter == i ? Color(0xff8917E3) : Colors.grey,
                ),
              ),
            ),
          ),
        const Spacer(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 검색창
            TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: '검색어를 입력하세요',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => setState(() {}),
            ),

            const SizedBox(height: 12),
            _buildFilterTabs(),
            const SizedBox(height: 12),

            // 검색 전: 추천 검색어 / 검색 후: 결과 리스트
            Expanded(
              child: query.isEmpty ? _buildSuggestions() : _buildResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('추천 검색어', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _suggestions.map((s) {
            return ActionChip(
              label: Text(s),
              onPressed: () {
                _controller.text = s;
                _controller.selection = TextSelection.collapsed(
                  offset: s.length,
                );
                setState(() {});
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildResults() {
    final results = _filteredResults;
    if (results.isEmpty) {
      return const Center(child: Text('검색 결과가 없습니다'));
    }
    return ListView.separated(
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, idx) {
        final r = results[idx];
        return Row(
          children: [
            // 앨범 자켓
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: r.albumImageUrl.isNotEmpty
                  ? Image.network(
                      r.albumImageUrl,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => Image.asset(
                        'assets/images/cat.webp',
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Image.asset(
                      'assets/images/cat.webp',
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    ),
            ),

            const SizedBox(width: 12),

            // 제목·가수명
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.songTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    r.singer,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
