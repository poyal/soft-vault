import 'package:flutter/material.dart';
import 'app_updater.dart';
import 'settings_components.dart';
import 'design.dart';

class UpdateSettings extends StatelessWidget {
  final Future<void> Function()? install;
  const UpdateSettings({super.key, this.install});
  @override
  Widget build(BuildContext context) {
    final updater = AppUpdater.instance;
    if (updater == null)
      return const SettingsSection(
        title: '업데이트',
        children: [SettingsStatus('업데이트 서비스가 준비되지 않았습니다.')],
      );
    return ListenableBuilder(
      listenable: updater,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsSection(
            title: 'Soft Vault',
            description: '컴퓨터의 영상을 재생하고 정리하는 미디어 라이브러리',
            children: [
              SettingsRow(
                title: '현재 버전',
                control: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'design/assets/app-icon.png',
                      width: 28,
                      height: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      updater.current,
                      style: const TextStyle(
                        fontSize: 14,
                        color: DeckDesign.text,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (updater.previousResult.isNotEmpty)
            SettingsStatus(updater.previousResult),
          SettingsSection(
            title: '업데이트',
            children: [
              SettingsRow(
                title: '자동으로 업데이트 확인',
                description: '하루 한 번 확인합니다. 다운로드와 설치는 직접 선택합니다.',
                control: Switch(
                  value: updater.automatic,
                  onChanged: updater.setAutomatic,
                ),
              ),
              SettingsRow(
                title: '새 버전 확인',
                description: updater.lastCheck == null
                    ? '아직 확인하지 않았습니다.'
                    : '마지막 확인: ${MaterialLocalizations.of(context).formatMediumDate(updater.lastCheck!.toLocal())} ${TimeOfDay.fromDateTime(updater.lastCheck!.toLocal()).format(context)}',
                control: OutlinedButton(
                  onPressed: updater.working ? null : updater.check,
                  child: const Text('지금 확인'),
                ),
              ),
              SettingsStatus(
                updater.message.isEmpty
                    ? '새 버전이 있는지 확인할 수 있습니다.'
                    : updater.message,
              ),
              if (updater.working)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: LinearProgressIndicator(value: updater.progress),
                ),
              if (updater.release != null || updater.ready)
                SettingsRow(
                  title: updater.ready
                      ? '설치 준비 완료'
                      : '새 버전 ${updater.release?['version'] ?? ''}',
                  description: updater.ready
                      ? '나중에 설치하려면 설정을 닫으세요. 진행 중인 작업은 먼저 완료해 주세요.'
                      : null,
                  control: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (!updater.ready)
                        FilledButton(
                          onPressed: updater.working ? null : updater.download,
                          child: const Text('다운로드'),
                        ),
                      if (updater.working && updater.progress != null)
                        OutlinedButton(
                          onPressed: updater.cancel,
                          child: const Text('취소'),
                        ),
                      if (updater.ready)
                        FilledButton(
                          onPressed: install,
                          child: const Text('업데이트 후 재시작'),
                        ),
                    ],
                  ),
                ),
            ],
          ),
          if (updater.notes.isNotEmpty)
            SettingsSection(
              title: '변경 사항',
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: SelectableText(
                    updater.notes,
                    style: const TextStyle(fontSize: 14, height: 1.6),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
