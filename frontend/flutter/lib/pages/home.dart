import 'package:flutter/material.dart';
import '../widgets/song_card.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top bar: App title and menu icon
          // Row(
          //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
          //   children: const [
          //     Text(
          //       'AVTS',
          //       style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          //     ),
          //     Icon(Icons.add_alert),
          //   ],
          // ),
          const SizedBox(height: 12),

          // Banner image placeholder
          Container(
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey.shade300,
              // Replace with AssetImage or NetworkImage
              // image: DecorationImage(
              //   image: AssetImage('assets/banner.jpg'),
              //   fit: BoxFit.cover,
              // ),
            ),
          ),

          const SizedBox(height: 20),

          // Section: Choose Your Vocal Trainer Level
          const Text(
            'Choose Your Vocal Trainer Level',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 180,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: const [
                LevelCard(
                  title: 'Beginner',
                  subtitle: '음정, 호흡 등 기본적인 보컬 기술',
                  duration: '1개월',
                  lessons: '150강',
                ),
                SizedBox(width: 12),
                LevelCard(
                  title: 'Intermediate',
                  subtitle: '다양한 장르와 테크닉 연습',
                  duration: '2개월',
                  lessons: '200강',
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Today's Song
          const Text(
            "Today's Song",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 150,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: const [
                SongCard(
                  imagePath: 'assets/images/iu.webp',
                  title: 'Never Ending Story',
                  artist: 'IU',
                ),
                SizedBox(width: 12),
                SongCard(
                  imagePath: 'assets/images/no_pain.webp',
                  title: 'Drowning',
                  artist: 'WOODZ',
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Vocal Tracking Progress
          const Text(
            'Vocal Tracking Progress',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(child: Text('Chart Placeholder')),
          ),

          const SizedBox(height: 20),

          // New Song Update
          const Text(
            'New Song Update',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 150,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: const [
                SongCard(
                  imagePath: 'assets/images/no_pain.webp',
                  title: 'NO PAIN',
                  artist: '실리카겔',
                ),
                SizedBox(width: 12),
                SongCard(
                  imagePath: 'assets/images/famous.webp',
                  title: 'FAMOUS',
                  artist: 'Allday Project',
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class LevelCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String duration;
  final String lessons;

  const LevelCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.duration,
    required this.lessons,
  }) : super();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                color: Colors.grey.shade300,
                // Replace with Image.asset or NetworkImage
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(duration, style: const TextStyle(fontSize: 12)),
                      const Spacer(),
                      Text(lessons, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
