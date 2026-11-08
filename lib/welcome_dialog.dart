import 'package:flutter/material.dart';
import 'design.dart';

class WelcomeDialog extends StatelessWidget {
  const WelcomeDialog({super.key});
  @override
  Widget build(BuildContext context) => Dialog(
    child: SizedBox(
      width: 700,
      height: 604,
      child: Stack(
        children: [
          Positioned(
            top: 20,
            left: 26,
            right: 20,
            child: Row(
              children: [
                const Text(
                  'SOFT VAULT',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                    color: DeckDesign.muted,
                  ),
                ),
                const Spacer(),
                DeckIconButton(
                  'close',
                  tooltip: '시작 안내 닫기',
                  onPressed: () => Navigator.pop(context, false),
                  extent: 48,
                ),
              ],
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(40, 76, 40, 30),
              child: Column(
                children: [
                  Image.asset(
                    'design/assets/app-icon.png',
                    width: 110,
                    height: 110,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '흩어진 장면들,\n나만의 라이브러리로.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '영상을 담아둔 폴더를 연결해 보세요.\n파일은 원래 자리에 두고, 여기서 함께 정리할 수 있어요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.9,
                      color: DeckDesign.muted,
                    ),
                  ),
                  const SizedBox(height: 26),
                  const Wrap(
                    spacing: 22,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      Text(
                        '✓  여러 폴더 연결',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xff8d9f76),
                        ),
                      ),
                      Text(
                        '✓  평점 · 배우 · 태그',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xff8d9f76),
                        ),
                      ),
                      Text(
                        '✓  항상 무음 시작',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xff8d9f76),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const DesignIcon(
                      'plus',
                      size: 16,
                      color: Color(0xff1e3549),
                    ),
                    label: const Text('폴더 연결하고 시작하기'),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '기록은 이 기기에 보관합니다.\n폴더를 연결해도 원본 파일을 변경하지 않습니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.6,
                      color: DeckDesign.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
