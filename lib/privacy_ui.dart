import 'dart:async';
import 'package:flutter/material.dart';
import 'window_lifecycle.dart';
import 'design.dart';
import 'privacy_lock.dart';

/// No home subtree, player, shortcut handlers or catalog loading before access
/// is granted. This is deliberately not a dismissible dialog over the library.
class PrivacyGate extends StatefulWidget {
  final PrivacyLock privacy;
  final Future<Widget> Function(VoidCallback lockNow) openHome;
  const PrivacyGate({super.key, required this.privacy, required this.openHome});
  @override
  State<PrivacyGate> createState() => _PrivacyGateState();
}

class _PrivacyGateState extends State<PrivacyGate> {
  PrivacyStatus? status;
  Widget? home;
  bool busy = true;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final next = await widget.privacy.status();
      if (!mounted) return;
      setState(() => status = next);
      if (next.configured && !next.enabled) await open();
    } catch (_) {
      if (mounted) setState(() => error = '잠금 정보를 읽을 수 없어 앱을 열지 않았습니다.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> open() async {
    final next = await widget.openHome(() {
      if (!mounted) return;
      setState(() {
        home = null;
        status = null;
      });
      load();
    });
    if (mounted) setState(() => home = next);
  }

  @override
  Widget build(BuildContext context) {
    if (home != null) return home!;
    return PopScope(
      canPop: false,
      child: Scaffold(
        key: const ValueKey('privacy-gate'),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Image.asset(
                      'design/assets/app-icon.png',
                      width: 64,
                      height: 64,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'soft vault.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 30),
                  if (error != null) ...[
                    Text(error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: busy ? null : load,
                      child: const Text('다시 시도'),
                    ),
                  ] else if (busy)
                    const Center(child: CircularProgressIndicator())
                  else if (status != null)
                    PrivacyForm(
                      key: ValueKey(status!.configured),
                      privacy: widget.privacy,
                      mode: status!.configured
                          ? PrivacyFormMode.unlock
                          : PrivacyFormMode.setup,
                      onSuccess: () async {
                        setState(() => busy = true);
                        try {
                          await open();
                        } catch (_) {
                          if (mounted)
                            setState(
                              () => error = '라이브러리를 열지 못했습니다. 다시 시도해 주세요.',
                            );
                        } finally {
                          if (mounted) setState(() => busy = false);
                        }
                      },
                    ),
                  if (!busy && error == null && status?.configured == false)
                    OutlinedButton(
                      onPressed: () async {
                        setState(() => busy = true);
                        try {
                          await widget.privacy.deferSetup();
                          await open();
                        } catch (_) {
                          if (mounted)
                            setState(() => error = '설정을 저장하지 못했습니다.');
                        } finally {
                          if (mounted) setState(() => busy = false);
                        }
                      },
                      child: const Text('나중에 설정'),
                    ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: closeAppWindow,
                    child: const Text('앱 종료'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum PrivacyFormMode { unlock, setup, change, disable }

class PrivacyForm extends StatefulWidget {
  final PrivacyLock privacy;
  final PrivacyFormMode mode;
  final Future<void> Function() onSuccess;
  const PrivacyForm({
    super.key,
    required this.privacy,
    required this.mode,
    required this.onSuccess,
  });
  @override
  State<PrivacyForm> createState() => _PrivacyFormState();
}

class _PrivacyFormState extends State<PrivacyForm> {
  final current = TextEditingController(),
      next = TextEditingController(),
      confirmation = TextEditingController();
  bool busy = false, visible = false;
  String? error;
  int retryAfter = 0;
  Timer? timer;
  bool get creates =>
      widget.mode == PrivacyFormMode.setup ||
      widget.mode == PrivacyFormMode.change;
  bool get asksCurrent => widget.mode != PrivacyFormMode.setup;
  int get remaining =>
      ((retryAfter - DateTime.now().millisecondsSinceEpoch) / 1000)
          .ceil()
          .clamp(0, 3600);
  @override
  void initState() {
    super.initState();
    refreshDelay();
  }

  Future<void> refreshDelay() async {
    try {
      final value = await widget.privacy.status();
      if (!mounted) return;
      setState(() => retryAfter = value.retryAfter);
      timer?.cancel();
      if (remaining > 0)
        timer = Timer.periodic(const Duration(seconds: 1), (t) {
          if (!mounted) {
            t.cancel();
            return;
          }
          setState(() {});
          if (remaining == 0) t.cancel();
        });
    } catch (_) {
      if (mounted) setState(() => error = '잠금 정보를 확인하지 못했습니다.');
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    current.dispose();
    next.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || remaining > 0) return;
    if (creates) {
      final invalid = PrivacyLock.validatePassword(next.text);
      if (invalid != null || next.text != confirmation.text) {
        setState(() => error = invalid ?? '새 비밀번호가 서로 다릅니다.');
        return;
      }
    } else if (current.text.isEmpty) {
      setState(() => error = '비밀번호를 입력해 주세요.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final accepted = switch (widget.mode) {
        PrivacyFormMode.unlock => await widget.privacy.authenticate(
          current.text,
        ),
        PrivacyFormMode.disable => await widget.privacy.disable(current.text),
        _ => await widget.privacy.setPassword(next.text, current: current.text),
      };
      if (!mounted) return;
      if (!accepted) {
        setState(() => error = '비밀번호가 맞지 않습니다.');
        await refreshDelay();
        return;
      }
      current.clear();
      next.clear();
      confirmation.clear();
      await widget.onSuccess();
    } on PrivacyDelay catch (e) {
      if (mounted) setState(() => error = e.toString());
      await refreshDelay();
    } catch (_) {
      if (mounted) setState(() => error = '잠금 설정을 처리하지 못했습니다. 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget field(
    TextEditingController controller,
    String label,
    String key, {
    bool autofocus = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextField(
      key: ValueKey(key),
      controller: controller,
      autofocus: autofocus,
      enabled: !busy,
      obscureText: !visible,
      autocorrect: false,
      enableSuggestions: false,
      enableIMEPersonalizedLearning: false,
      maxLength: 128,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => submit(),
      decoration: InputDecoration(labelText: label, counterText: ''),
    ),
  );
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(switch (widget.mode) {
        PrivacyFormMode.unlock => '비밀번호를 입력해 주세요',
        PrivacyFormMode.setup => '앱 시작 비밀번호 설정',
        PrivacyFormMode.change => '비밀번호 변경',
        PrivacyFormMode.disable => '비밀번호 잠금 해제',
      }, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      Text(
        creates
            ? '8~128자로 설정하세요. 비밀번호를 잊으면 앱에서 복구할 수 없습니다.'
            : widget.mode == PrivacyFormMode.disable
            ? '현재 비밀번호를 확인하면 다음 실행부터 입력 없이 열립니다.'
            : '잠금을 풀기 전에는 라이브러리가 표시되지 않습니다.',
        style: const TextStyle(fontSize: 14, color: DeckDesign.muted),
      ),
      const SizedBox(height: 20),
      if (asksCurrent)
        field(
          current,
          widget.mode == PrivacyFormMode.unlock ? '비밀번호' : '현재 비밀번호',
          'privacy-current',
          autofocus: true,
        ),
      if (creates) ...[
        field(next, '새 비밀번호', 'privacy-new', autofocus: !asksCurrent),
        field(confirmation, '새 비밀번호 확인', 'privacy-confirm'),
      ],
      Material(
        type: MaterialType.transparency,
        child: CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text('비밀번호 표시'),
          value: visible,
          onChanged: busy ? null : (value) => setState(() => visible = value!),
        ),
      ),
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            error!,
            key: const ValueKey('privacy-error'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      if (remaining > 0)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text('여러 번 틀렸습니다. $remaining초 후 다시 시도해 주세요.'),
        ),
      FilledButton(
        key: const ValueKey('privacy-submit'),
        onPressed: busy || remaining > 0 ? null : submit,
        child: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(switch (widget.mode) {
                PrivacyFormMode.unlock => '잠금 풀기',
                PrivacyFormMode.setup => '비밀번호 설정',
                PrivacyFormMode.change => '비밀번호 변경',
                PrivacyFormMode.disable => '잠금 기능 끄기',
              }),
      ),
    ],
  );
}

class PrivacySettings extends StatefulWidget {
  final PrivacyLock? privacy;
  final Future<void> Function()? lockNow;
  const PrivacySettings({super.key, this.privacy, this.lockNow});
  @override
  State<PrivacySettings> createState() => _PrivacySettingsState();
}

class _PrivacySettingsState extends State<PrivacySettings> {
  PrivacyStatus? status;
  PrivacyFormMode? mode;
  String? error, message;
  bool locking = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final next = await widget.privacy?.status();
      if (mounted)
        setState(() {
          status = next;
          error = null;
        });
    } catch (_) {
      if (mounted) setState(() => error = '잠금 설정을 읽지 못했습니다.');
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        '앱 시작 비밀번호',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 10),
      const Text(
        '앱을 새로 열 때 비밀번호를 확인합니다.\n앱 접근을 잠그는 기능이며 원본 영상 파일을 암호화하지 않습니다.',
        style: TextStyle(fontSize: 14, color: DeckDesign.muted),
      ),
      const SizedBox(height: 20),
      if (widget.privacy == null)
        const Text('사생활 보호 설정을 불러오지 못했습니다.')
      else if (error != null)
        Text(error!)
      else if (status == null)
        const CircularProgressIndicator()
      else if (mode != null)
        SizedBox(
          width: 420,
          child: Column(
            children: [
              PrivacyForm(
                key: ValueKey(mode),
                privacy: widget.privacy!,
                mode: mode!,
                onSuccess: () async {
                  setState(() {
                    mode = null;
                    message = '잠금 설정을 저장했습니다.';
                  });
                  await load();
                },
              ),
              OutlinedButton(
                onPressed: () => setState(() => mode = null),
                child: const Text('돌아가기'),
              ),
            ],
          ),
        )
      else ...[
        Chip(
          avatar: Icon(
            status!.enabled ? Icons.lock_outline : Icons.lock_open,
            size: 16,
          ),
          label: Text(status!.enabled ? '비밀번호 보호 켜짐' : '비밀번호 보호 꺼짐'),
        ),
        const SizedBox(height: 16),
        if (message != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(message!),
          ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton(
              onPressed: () => setState(
                () => mode = status!.enabled
                    ? PrivacyFormMode.change
                    : PrivacyFormMode.setup,
              ),
              child: Text(status!.enabled ? '비밀번호 변경' : '비밀번호 설정'),
            ),
            if (status!.enabled) ...[
              OutlinedButton(
                onPressed: () => setState(() => mode = PrivacyFormMode.disable),
                child: const Text('잠금 기능 끄기'),
              ),
              OutlinedButton(
                onPressed: widget.lockNow == null || locking
                    ? null
                    : () async {
                        setState(() => locking = true);
                        try {
                          await widget.lockNow!();
                        } finally {
                          if (mounted) setState(() => locking = false);
                        }
                      },
                child: const Text('지금 잠그기'),
              ),
            ],
          ],
        ),
      ],
    ],
  );
}
