import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

void main() {
  runApp(const AxonRecorderApp());
}

const String kUiFont = 'Vazirmatn';
const String kNastaliqFont = 'IranNastaliq';
const String kTelegramUsername = 'pouyabaniadam';

class AxonRecorderApp extends StatelessWidget {
  const AxonRecorderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ضبط صدا برای هی آکسون',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B0C14),
        textTheme: ThemeData.dark().textTheme.apply(fontFamily: kUiFont),
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: RecorderHomePage(),
      ),
    );
  }
}

class PromptItem {
  final String category;
  final String slug;
  final String title;
  final String desc;
  const PromptItem(this.category, this.slug, this.title, this.desc);
}

const List<PromptItem> kPrompts = [
  PromptItem('لحن عادی', 'normal_01', '۱. عادی و طبیعی', 'خیلی معمولی و روزمره بگو: «هی آکسون»'),
  PromptItem('سرعت بالا', 'fast_01', '۲. سریع و خودمونی', 'کمی تندتر و محاوره‌ای بگو: «هی آکسون»'),
  PromptItem('صدای آرام', 'quiet_01', '۳. آروم و یواش', 'با صدای آروم بگو: «هی آکسون»'),
  PromptItem('صدای بلند', 'loud_01', '۴. بلند و رسا', 'با صدای بلند و واضح بگو: «هی آکسون»'),
  PromptItem('تنوع لحن', 'question_01', '۵. لحن پرسشی', 'انگار سوال می‌پرسی بگو: «هی آکسون؟»'),
  PromptItem('سناریو واقعی', 'before_cmd', '۶. قبل از دستور', 'انگار می‌خوای کاری بهش بسپاری بگو: «هی آکسون»'),

  PromptItem('لحن عادی', 'normal_02', '۷. عادی (تکرار دوم)', 'دوباره معمولی و طبیعی بگو: «هی آکسون»'),
  PromptItem('سرعت بالا', 'very_fast', '۸. خیلی سریع و سرهم', 'پشت سر هم و سریع بگو: «هی‌آکسون»'),
  PromptItem('صدای آرام', 'whisper_01', '۹. نجوا / نصف شب', 'خیلی یواش و نزدیک میکروفون بگو: «هی آکسون»'),
  PromptItem('صدای بلند', 'energetic_01', '۱۰. پرانرژی و محکم', 'خیلی پرانرژی و محکم بگو: «هی آکسون!»'),
  PromptItem('تنوع لحن', 'tired_stretched', '۱۱. خسته و کشیده', 'با لحن خسته و ریلکس بگو: «هِــی آکسون»'),
  PromptItem('سناریو واقعی', 'short_pause', '۱۲. با مکث کوتاه وسطش', 'با نیم ثانیه مکث بگو: «هی... آکسون»'),

  PromptItem('لحن عادی', 'normal_03', '۱۳. عادی (تکرار سوم)', 'یک بار دیگر معمولی بگو: «هی آکسون»'),
  PromptItem('صدای بلند', 'far_2m_01', '۱۴. صدا زدن از فاصله ۲ متری', 'کمی از سیستم فاصله بگیر و بگو: «هی آکسون»'),
  PromptItem('تنوع لحن', 'friendly_smile', '۱۵. خوشحال و صمیمی', 'با لبخند و لحن صمیمی بگو: «هی آکسون»'),
  PromptItem('سرعت بالا', 'hurried', '۱۶. عجله‌ای', 'انگار عجله داری بگو: «هی آکسون!»'),
  PromptItem('صدای آرام', 'soft_clear', '۱۷. ملایم و شمرده', 'آروم و شمرده بگو: «هی آکسون»'),
  PromptItem('سناریو واقعی', 'turned_right', '۱۸. چرخیده به سمت راست', 'سرت رو بچرخون سمت راست و بگو: «هی آکسون»'),

  PromptItem('لحن عادی', 'normal_04', '۱۹. عادی (تکرار چهارم)', 'معمولی و روان بگو: «هی آکسون»'),
  PromptItem('تنوع لحن', 'serious_cmd', '۲۰. جدی و دستوری', 'با لحن جدی و قاطع بگو: «هی آکسون»'),
  PromptItem('سرعت بالا', 'fast_short', '۲۱. سریع و کوتاه', 'خیلی سریع و بریده بگو: «هی آکسون»'),
  PromptItem('صدای بلند', 'loud_02', '۲۲. بلند (تکرار دوم)', 'دوباره با صدای بلند بگو: «هی آکسون»'),
  PromptItem('صدای آرام', 'morning_voice', '۲۳. صدای صبحگاهی', 'انگار تازه بیدار شدی بگو: «هی آکسون»'),
  PromptItem('سناریو واقعی', 'turned_left', '۲۴. چرخیده به سمت چپ', 'سرت رو بچرخون سمت چپ و بگو: «هی آکسون»'),

  PromptItem('لحن عادی', 'normal_05', '۲۵. عادی (تکرار پنجم)', 'دوباره عادی بگو: «هی آکسون»'),
  PromptItem('تنوع لحن', 'question_02', '۲۶. لحن پرسشی (تکرار)', 'دوباره با لحن سوالی بگو: «هی آکسون؟»'),
  PromptItem('سناریو واقعی', 'leaned_back', '۲۷. تکیه داده به صندلی', 'کاملاً لم بده و بگو: «هی آکسون»'),
  PromptItem('سرعت بالا', 'busy_fast', '۲۸. وسط کار با عجله', 'انگار سرت شلوغه بگو: «هی آکسون»'),
  PromptItem('صدای آرام', 'quiet_02', '۲۹. آروم (تکرار دوم)', 'دوباره آروم بگو: «هی آکسون»'),
  PromptItem('صدای بلند', 'energetic_02', '۳۰. پرانرژی (تکرار دوم)', 'دوباره با انرژی بالا بگو: «هی آکسون!»'),

  PromptItem('لحن عادی', 'normal_06', '۳۱. عادی (تکرار ششم)', 'با ریتم طبیعی خودت بگو: «هی آکسون»'),
  PromptItem('تنوع لحن', 'stretch_axon', '۳۲. کشیده روی آکسون', 'بگو: «هی آکســـون»'),
  PromptItem('سناریو واقعی', 'looking_down', '۳۳. رو به پایین', 'سرت رو پایین بگیر و بگو: «هی آکسون»'),
  PromptItem('تنوع لحن', 'annoyed_frown', '۳۴. کلافه یا اخمو', 'با لحن کمی جدی و اخمو بگو: «هی آکسون»'),
  PromptItem('صدای آرام', 'whisper_02', '۳۵. نجوا (تکرار دوم)', 'دوباره خیلی یواش بگو: «هی آکسون»'),
  PromptItem('صدای بلند', 'far_2m_02', '۳۶. صدا زدن از دور (تکرار)', 'از دور و با صدای بلند بگو: «هی آکسون»'),

  PromptItem('لحن عادی', 'normal_07', '۳۷. عادی (تکرار هفتم)', 'خیلی ریلکس و عادی بگو: «هی آکسون»'),
  PromptItem('تنوع لحن', 'stretch_hey', '۳۸. کشیده روی هی', 'بگو: «هِـــی آکسون»'),
  PromptItem('سناریو واقعی', 'close_mic', '۳۹. خیلی نزدیک به میکروفون', 'نزدیک میکروفون بگو: «هی آکسون»'),
  PromptItem('سرعت بالا', 'fast_02', '۴۰. سریع (تکرار دوم)', 'دوباره تند و سریع بگو: «هی آکسون»'),
  PromptItem('سناریو واقعی', 'walking_room', '۴۱. در حال راه رفتن در اتاق', 'کمی حرکت کن و بگو: «هی آکسون»'),
  PromptItem('لحن عادی', 'normal_08', '۴۲. عادی (تکرار هشتم)', 'دوباره معمولی بگو: «هی آکسون»'),

  PromptItem('محیط پرنویز', 'noisy_music_01', '۴۳. با صدای موزیک یا تلویزیون', 'یه آهنگ یا ویدیو پخش کن و بگو: «هی آکسون»'),
  PromptItem('محیط پرنویز', 'noisy_music_02', '۴۴. با موزیک در پس‌زمینه (۲)', 'دوباره با صدای پس‌زمینه بگو: «هی آکسون»'),
  PromptItem('محیط پرنویز', 'noisy_typing', '۴۵. همراه با صدای تایپ کیبورد', 'حین زدن دکمه‌های کیبورد بگو: «هی آکسون»'),
  PromptItem('محیط پرنویز', 'noisy_ambient', '۴۶. با صدای محیط (پنکه/پنجره)', 'در حالت عادی اتاق بگو: «هی آکسون»'),
  PromptItem('محیط پرنویز', 'noisy_loud', '۴۷. صدای بلندتر از موزیک', 'روی صدای آهنگ بگو: «هی آکسون»'),
  PromptItem('محیط پرنویز', 'noisy_fast', '۴۸. سریع با نویز محیط', 'تند و با صدای پس‌زمینه بگو: «هی آکسون»'),
  PromptItem('محیط پرنویز', 'noisy_normal', '۴۹. عادی با نویز محیط', 'معمولی با صدای پس‌زمینه بگو: «هی آکسون»'),
  PromptItem('محیط پرنویز', 'freestyle_final', '۵۰. آخرین بار به دلخواه خودت!', 'هر طور راحت‌تری بگو: «هی آکسون»'),
];

class RecorderHomePage extends StatefulWidget {
  const RecorderHomePage({super.key});

  @override
  State<RecorderHomePage> createState() => _RecorderHomePageState();
}

class _RecorderHomePageState extends State<RecorderHomePage> {
  final _nameCtrl = TextEditingController();
  final _recorder = AudioRecorder();
  final _focusNode = FocusNode();

  int _screen = 0;
  int _step = 0;
  bool _isRecording = false;
  bool _isLoading = true;
  double _amplitude = 0.0;
  StreamSubscription<Amplitude>? _ampSub;
  String _userName = 'speaker';
  String _statusText = 'روی دکمه بزن (یا Space) و بگو «هی آکسون»';
  String _zipPath = '';

  Directory? _sessionDir;
  File? _stateFile;
  final List<String?> _recordedPaths = List.filled(kPrompts.length, null);

  bool _hasSavedSession = false;
  String _savedUserName = '';
  int _savedStep = 0;
  List<String?> _savedPaths = List.filled(kPrompts.length, null);

  @override
  void initState() {
    super.initState();
    _initStorageAndCheckResume();
  }

  @override
  void dispose() {
    _ampSub?.cancel();
    _recorder.dispose();
    _nameCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _initStorageAndCheckResume() async {
    final supportDir = await getApplicationSupportDirectory();
    _sessionDir = Directory('${supportDir.path}/axon_session');
    if (!await _sessionDir!.exists()) {
      await _sessionDir!.create(recursive: true);
    }
    _stateFile = File('${_sessionDir!.path}/session_state.json');

    if (await _stateFile!.exists()) {
      try {
        final content = await _stateFile!.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;
        final user = (data['userName'] as String?) ?? 'speaker';
        final completed = (data['completed'] as bool?) ?? false;
        final savedZip = (data['zipPath'] as String?) ?? '';

        if (completed && savedZip.isNotEmpty && await File(savedZip).exists()) {
          _userName = user;
          _zipPath = savedZip;
          _screen = 2;
        } else {
          final step = (data['step'] as int?) ?? 0;
          final rawPaths = (data['paths'] as List<dynamic>?) ?? [];

          final restoredPaths = List<String?>.filled(kPrompts.length, null);
          int validCount = 0;
          for (int i = 0; i < min(rawPaths.length, kPrompts.length); i++) {
            final p = rawPaths[i] as String?;
            if (p != null && await File(p).exists()) {
              restoredPaths[i] = p;
              validCount++;
            }
          }

          if (validCount > 0 && step < kPrompts.length) {
            _hasSavedSession = true;
            _savedUserName = user;
            _savedStep = step;
            _savedPaths = restoredPaths;
          }
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProgress({bool completed = false, String zipPath = ''}) async {
    if (_stateFile == null) return;
    final payload = {
      'userName': _userName,
      'step': _step,
      'paths': _recordedPaths,
      'completed': completed,
      'zipPath': zipPath,
    };
    await _stateFile!.writeAsString(jsonEncode(payload));
  }

  Future<void> _clearSavedProgress() async {
    if (_stateFile != null && await _stateFile!.exists()) {
      await _stateFile!.delete();
    }
    if (_sessionDir != null && await _sessionDir!.exists()) {
      await for (final entity in _sessionDir!.list()) {
        if (entity is File && entity.path.endsWith('.wav')) {
          await entity.delete();
        }
      }
    }
  }

  Future<void> _resetToStartScreen() async {
    await _clearSavedProgress();
    for (int i = 0; i < _recordedPaths.length; i++) {
      _recordedPaths[i] = null;
    }
    setState(() {
      _hasSavedSession = false;
      _zipPath = '';
      _step = 0;
      _amplitude = 0.0;
      _screen = 0;
    });
  }

  Future<void> _confirmAndResetFromRecordScreen() async {
    if (_isRecording) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text(
            'شروع مجدد از صفر؟',
            style: TextStyle(color: Color(0xFFF9E2AF), fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'با این کار تمام مراحل ضبط‌شده فعلی پاک می‌شن و به صفحه اول برمی‌گردی. مطمئنی؟',
            style: TextStyle(color: Color(0xFFBAC2DE), height: 1.6),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('انصراف', style: TextStyle(color: Color(0xFFA6ADC8))),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF38BA8),
                foregroundColor: const Color(0xFF11111B),
              ),
              child: const Text('بله، از نو شروع کن', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      await _resetToStartScreen();
    } else {
      _focusNode.requestFocus();
    }
  }

  Future<bool> _ensureMicPermission() async {
    final hasPerm = await _recorder.hasPermission();
    if (!hasPerm && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('دسترسی به میکروفون تایید نشد!')),
      );
    }
    return hasPerm;
  }

  Future<void> _startNewSession() async {
    if (!await _ensureMicPermission()) return;

    final raw = _nameCtrl.text.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    _userName = raw.isEmpty ? 'speaker' : raw;

    await _clearSavedProgress();
    for (int i = 0; i < _recordedPaths.length; i++) {
      _recordedPaths[i] = null;
    }

    setState(() {
      _hasSavedSession = false;
      _screen = 1;
      _step = 0;
      _amplitude = 0.0;
      _statusText = 'روی دکمه بزن (یا Space) و بگو «هی آکسون»';
    });
    _focusNode.requestFocus();
  }

  Future<void> _resumeSavedSession() async {
    if (!await _ensureMicPermission()) return;

    _userName = _savedUserName;
    for (int i = 0; i < kPrompts.length; i++) {
      _recordedPaths[i] = _savedPaths[i];
    }

    setState(() {
      _screen = 1;
      _step = _savedStep;
      _amplitude = 0.0;
      _statusText = 'ادامه ضبط از مرحله ${_savedStep + 1}...';
    });
    _focusNode.requestFocus();
  }

  double _mapAmplitude(double db) {
    if (!db.isFinite || db <= -42.0) return 0.0;
    final norm = ((db + 42.0) / 34.0).clamp(0.0, 1.0);
    return pow(norm, 1.65).toDouble();
  }

  Future<void> _toggleRecord() async {
    if (!_isRecording) {
      final stepStr = (_step + 1).toString().padLeft(2, '0');
      final slug = kPrompts[_step].slug;
      final fileName = '${_userName}_${stepStr}_$slug.wav';
      final path = '${_sessionDir!.path}/$fileName';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: path,
      );

      await _ampSub?.cancel();
      _ampSub = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 45))
          .listen((amp) {
        if (!mounted || !_isRecording) return;
        setState(() {
          _amplitude = _mapAmplitude(amp.current);
        });
      });

      setState(() {
        _isRecording = true;
        _amplitude = 0.0;
        _statusText = '● در حال ضبط... بگو «هی آکسون» و دوباره بزن';
      });
    } else {
      await _ampSub?.cancel();
      _ampSub = null;
      final path = await _recorder.stop();
      setState(() {
        _isRecording = false;
        _amplitude = 0.0;
      });

      if (path != null) {
        _recordedPaths[_step] = path;
        if (_step + 1 >= kPrompts.length) {
          await _createZipAndFinish();
        } else {
          setState(() {
            _step++;
            _statusText = '✓ ذخیره شد! پیشرفتت هم خودکار ثبت شد.';
          });
          await _saveProgress();
        }
      }
    }
  }

  Future<void> _prevStep() async {
    if (_isRecording || _step == 0) return;
    setState(() {
      _step--;
      _statusText = 'برگشتی به مرحله قبل؛ دوباره ضبط کن';
    });
    await _saveProgress();
  }

  Future<void> _createZipAndFinish() async {
    final archive = Archive();
    for (final path in _recordedPaths) {
      if (path == null) continue;
      final file = File(path);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final name = file.uri.pathSegments.last;
        archive.addFile(ArchiveFile(name, bytes.length, bytes));
      }
    }

    final zipBytes = ZipEncoder().encode(archive);
    final outDir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    final outFile = File('${outDir.path}/axon_voices_$_userName.zip');
    await outFile.writeAsBytes(zipBytes!);

    if (_sessionDir != null && await _sessionDir!.exists()) {
      await for (final entity in _sessionDir!.list()) {
        if (entity is File && entity.path.endsWith('.wav')) {
          await entity.delete();
        }
      }
    }

    await _saveProgress(completed: true, zipPath: outFile.path);

    setState(() {
      _zipPath = outFile.path;
      _screen = 2;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: HeyAxonRainBackground()),
          Positioned.fill(
            child: Container(color: const Color(0xFF0B0C14).withAlpha(115)),
          ),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Container(
                  width: 460,
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: const Color(0xFF181926).withAlpha(220),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFF89B4FA).withAlpha(65),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(140),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    height: 180,
                    child: Center(child: CircularProgressIndicator()),
                  )
                      : _screen == 0
                      ? _buildStartScreen()
                      : _screen == 1
                      ? _buildRecordScreen()
                      : _buildDoneScreen(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartScreen() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF89B4FA).withAlpha(30),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.mic_rounded, size: 36, color: Color(0xFF89B4FA)),
        ),
        const SizedBox(height: 14),
        const Text(
          'ضبط صدای «هی آکسون»',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFF9E2AF)),
        ),
        const SizedBox(height: 10),
        const Text(
          '۵۰ مرحله کوتاه و متنوع داریم.\nهر زمان خسته شدی، برنامه رو ببند؛ سری بعد از ادامه‌اش میره!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13.5, color: Color(0xFFBAC2DE), height: 1.7),
        ),
        if (_hasSavedSession) ...[
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFA6E3A1).withAlpha(22),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFA6E3A1).withAlpha(90)),
            ),
            child: Column(
              children: [
                Text(
                  'یک ضبط ناتمام برای «$_savedUserName» وجود دارد (مرحله ${_savedStep + 1} از ${kPrompts.length})',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Color(0xFFA6E3A1), fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: _resumeSavedSession,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(
                      'ادامه از مرحله ${_savedStep + 1}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFA6E3A1),
                      foregroundColor: const Color(0xFF11111B),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'یا شروع یک ضبط جدید از ابتدا:',
            style: TextStyle(fontSize: 12, color: Color(0xFF7F849C)),
          ),
        ],
        const SizedBox(height: 14),
        TextField(
          controller: _nameCtrl,
          textAlign: TextAlign.center,
          onSubmitted: (_) => _startNewSession(),
          decoration: InputDecoration(
            hintText: 'اسمت (انگلیسی، مثلاً ali)',
            hintStyle: const TextStyle(color: Color(0xFF6C7086)),
            filled: true,
            fillColor: const Color(0xFF24273A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _startNewSession,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF89B4FA),
              foregroundColor: const Color(0xFF11111B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
              _hasSavedSession ? 'شروع جدید از صفر' : 'شروع ضبط',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecordScreen() {
    final prompt = kPrompts[_step];
    final progress = (_step + 1) / kPrompts.length;

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.space) {
          _toggleRecord();
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF89B4FA).withAlpha(35),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  prompt.category,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF89B4FA), fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                'مرحله ${_step + 1} از ${kPrompts.length}',
                style: const TextStyle(fontSize: 13, color: Color(0xFFA6ADC8)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: const Color(0xFF313244),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF89B4FA)),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            prompt.title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFF9E2AF)),
          ),
          const SizedBox(height: 8),
          Text(
            prompt.desc,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: Color(0xFFCDD6F4)),
          ),
          const SizedBox(height: 16),
          SiriOrbVisualizer(
            isRecording: _isRecording,
            amplitude: _amplitude,
            onTap: _toggleRecord,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _toggleRecord,
              icon: Icon(_isRecording ? Icons.stop_rounded : Icons.mic_rounded, size: 24),
              label: Text(
                _isRecording ? 'در حال ضبط... (برای توقف بزن)' : 'شروع ضبط  (Space)',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isRecording ? const Color(0xFFF38BA8) : const Color(0xFFA6E3A1),
                foregroundColor: const Color(0xFF11111B),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _statusText,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: _isRecording ? const Color(0xFFF38BA8) : const Color(0xFF9399B2),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: _step > 0 && !_isRecording ? _prevStep : null,
                icon: const Icon(Icons.undo_rounded, size: 18),
                label: const Text('مرحله قبل'),
              ),
              TextButton.icon(
                onPressed: !_isRecording ? _confirmAndResetFromRecordScreen : null,
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: const Text('شروع مجدد از صفر'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFF38BA8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDoneScreen() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle_rounded, size: 54, color: Color(0xFFA6E3A1)),
        const SizedBox(height: 14),
        const Text(
          'دمت گرم! تمام شد 🎉',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFA6E3A1)),
        ),
        const SizedBox(height: 10),
        const Text(
          'فایل زیپ ۵۰ صدا در مسیر زیر ذخیره شد. همینو توی تلگرام برام بفرست:',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Color(0xFFBAC2DE), height: 1.6),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF24273A),
            borderRadius: BorderRadius.circular(12),
          ),
          child: SelectableText(
            _zipPath,
            textDirection: TextDirection.ltr,
            style: const TextStyle(fontSize: 12, color: Color(0xFF89B4FA)),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _zipPath));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('مسیر فایل کپی شد!')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('کپی کردن مسیر فایل', style: TextStyle(fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFCDD6F4),
              side: const BorderSide(color: Color(0xFF45475A)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(const ClipboardData(text: '@$kTelegramUsername'));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('آیدی تلگرام (@$kTelegramUsername) کپی شد!')),
              );
            },
            icon: const Icon(Icons.alternate_email_rounded, size: 18),
            label: const Text(
              'کپی کردن آیدی تلگرام (@$kTelegramUsername)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF24A1DE),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: _resetToStartScreen,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('شروع ضبط جدید از صفر'),
        ),
      ],
    );
  }
}

class SiriOrbVisualizer extends StatefulWidget {
  final bool isRecording;
  final double amplitude;
  final VoidCallback? onTap;

  const SiriOrbVisualizer({
    super.key,
    required this.isRecording,
    required this.amplitude,
    this.onTap,
  });

  @override
  State<SiriOrbVisualizer> createState() => _SiriOrbVisualizerState();
}

class _SiriOrbVisualizerState extends State<SiriOrbVisualizer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;
  double _time = 0.0;
  double _smoothAmp = 0.0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final dt = (elapsed - _lastElapsed).inMicroseconds / 1e6;
      _lastElapsed = elapsed;
      if (dt > 0 && dt < 0.2) {
        final target = widget.isRecording ? widget.amplitude.clamp(0.0, 1.0) : 0.0;
        final rate = target > _smoothAmp ? 20.0 : 9.5;
        _smoothAmp += (target - _smoothAmp) * (1.0 - exp(-dt * rate));
        if (_smoothAmp < 0.001) _smoothAmp = 0.0;
        final speed = widget.isRecording ? (0.45 + _smoothAmp * 3.8) : 0.35;
        _time += dt * speed;
        setState(() {});
      }
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: 136,
          height: 136,
          child: CustomPaint(
            painter: _SiriOrbPainter(
              time: _time,
              amplitude: _smoothAmp,
              isRecording: widget.isRecording,
            ),
          ),
        ),
      ),
    );
  }
}

class _SiriOrbPainter extends CustomPainter {
  final double time;
  final double amplitude;
  final bool isRecording;

  _SiriOrbPainter({
    required this.time,
    required this.amplitude,
    required this.isRecording,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final voice = isRecording ? amplitude : 0.0;
    final idlePulse = isRecording ? (sin(time * 2.0) * 0.4) : (sin(time * 1.1) * 0.6);
    final baseR = (size.width * 0.24) + (voice * 17.5) + idlePulse;

    final haloPaint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        baseR * (1.35 + voice * 0.55),
        [
          const Color(0xFF00E5FF).withAlpha((28 + voice * 115).toInt().clamp(0, 255)),
          const Color(0xFFFF2A85).withAlpha((12 + voice * 75).toInt().clamp(0, 255)),
          Colors.transparent,
        ],
        const [0.0, 0.55, 1.0],
      );
    canvas.drawCircle(center, baseR * (1.35 + voice * 0.55), haloPaint);

    canvas.saveLayer(Offset.zero & size, Paint());

    const blobs = [
      (
      colorA: Color(0xFF00F0FF),
      colorB: Color(0xFF2979FF),
      phase: 0.0,
      dir: 1.0,
      offsetAngle: 0.0,
      scale: 1.0,
      ),
      (
      colorA: Color(0xFFFF2E93),
      colorB: Color(0xFF7B2CBF),
      phase: 2.1,
      dir: -1.15,
      offsetAngle: 2.1,
      scale: 0.97,
      ),
      (
      colorA: Color(0xFF9D4EDD),
      colorB: Color(0xFF00BBF9),
      phase: 4.2,
      dir: 0.85,
      offsetAngle: 4.2,
      scale: 0.94,
      ),
      (
      colorA: Color(0xFF64FFDA),
      colorB: Color(0xFF536DFE),
      phase: 1.1,
      dir: -0.75,
      offsetAngle: 5.1,
      scale: 0.91,
      ),
    ];

    final wobbleStrength = voice < 0.02 ? 0.35 : (0.5 + voice * 18.5);
    final orbitDist = voice < 0.02 ? 0.3 : (0.4 + voice * 9.5);
    final activeMix = isRecording ? (0.35 + voice * 0.65) : 0.25;

    for (final b in blobs) {
      final bx = center.dx + cos(time * 0.9 * b.dir + b.offsetAngle) * orbitDist;
      final by = center.dy + sin(time * 1.1 * b.dir + b.offsetAngle) * orbitDist;
      final blobCenter = Offset(bx, by);
      final rBase = baseR * b.scale;

      final path = Path();
      const steps = 90;
      for (int i = 0; i <= steps; i++) {
        final theta = (i / steps) * 2 * pi;
        final wave1 = sin(2 * theta + time * 1.7 * b.dir + b.phase);
        final wave2 = cos(3 * theta - time * 1.3 * b.dir + b.phase * 1.5);
        final wave3 = sin(4 * theta + time * 2.2 * b.dir);
        final r = rBase + wobbleStrength * (wave1 * 0.5 + wave2 * 0.35 + wave3 * 0.15);
        final x = blobCenter.dx + cos(theta) * r;
        final y = blobCenter.dy + sin(theta) * r;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();

      final blobPaint = Paint()
        ..blendMode = BlendMode.plus
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3.5 + voice * 4.5)
        ..shader = ui.Gradient.radial(
          blobCenter,
          rBase + wobbleStrength,
          [
            b.colorA.withAlpha((85 * activeMix + 55).toInt().clamp(0, 255)),
            b.colorB.withAlpha((65 * activeMix + 35).toInt().clamp(0, 255)),
            b.colorB.withAlpha(0),
          ],
          const [0.1, 0.72, 1.0],
        );

      canvas.drawPath(path, blobPaint);
    }

    final corePaint = Paint()
      ..blendMode = BlendMode.plus
      ..shader = ui.Gradient.radial(
        center,
        baseR * 0.65,
        [
          Colors.white.withAlpha((60 + voice * 140).toInt().clamp(0, 255)),
          const Color(0xFFE0F7FA).withAlpha((20 + voice * 75).toInt().clamp(0, 255)),
          Colors.transparent,
        ],
        const [0.0, 0.45, 1.0],
      );
    canvas.drawCircle(center, baseR * 0.65, corePaint);

    canvas.restore();

    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 + voice * 0.8
      ..color = Colors.white.withAlpha((32 + voice * 75).toInt().clamp(0, 255));
    canvas.drawCircle(center, baseR * 0.96, rimPaint);
  }

  @override
  bool shouldRepaint(covariant _SiriOrbPainter oldDelegate) => true;
}

class _RainColorScheme {
  final Color headColor;
  final Color tailColor;
  const _RainColorScheme({required this.headColor, required this.tailColor});
}

class _FallingAxonText {
  late double x;
  late double y;
  late double z;
  late double speed;
  late String label;
  late _RainColorScheme colorScheme;
  late double fontSize;
  late int alpha;

  final Random random;
  final Size screenSize;

  static const double minFontSize = 18.0;
  static const double maxFontSize = 44.0;
  static const double minSpeed = 0.4;
  static const double maxSpeed = 1.6;
  static const int minAlpha = 75;
  static const int maxAlpha = 225;

  static const List<String> _phrases = [
    'هی آکسون',
    'هی آکسون...',
    'هی آکسون!',
    'هی آکسون؟',
  ];

  static const List<_RainColorScheme> _schemes = [
    _RainColorScheme(headColor: Color(0xffC8FFC8), tailColor: Color(0xff00FF41)),
    _RainColorScheme(headColor: Color(0xffE0FFFF), tailColor: Color(0xff00BFFF)),
    _RainColorScheme(headColor: Color(0xffFFFFA0), tailColor: Color(0xffFFBF00)),
    _RainColorScheme(headColor: Color(0xffE6E6FA), tailColor: Color(0xff9932CC)),
    _RainColorScheme(headColor: Color(0xFFF0FFFF), tailColor: Color(0xFF40E0D0)),
  ];

  _FallingAxonText({
    required this.x,
    required this.random,
    required this.screenSize,
  }) {
    _initialize(isInitial: true);
  }

  void _initialize({bool isInitial = false}) {
    y = isInitial
        ? -random.nextDouble() * screenSize.height * 1.4
        : -300 - random.nextDouble() * 400;
    z = random.nextDouble();
    fontSize = ui.lerpDouble(minFontSize, maxFontSize, z)!;
    speed = ui.lerpDouble(minSpeed, maxSpeed, z)!;
    alpha = ui.lerpDouble(minAlpha, maxAlpha, z)!.toInt();
    label = _phrases[random.nextInt(_phrases.length)];
    colorScheme = _schemes[random.nextInt(_schemes.length)];
  }

  void update(double speedFactor) {
    y += speed * speedFactor;
    if (y > screenSize.height + 350) {
      _initialize();
    }
  }
}

class HeyAxonRainBackground extends StatefulWidget {
  const HeyAxonRainBackground({super.key});

  @override
  State<HeyAxonRainBackground> createState() => _HeyAxonRainBackgroundState();
}

class _HeyAxonRainBackgroundState extends State<HeyAxonRainBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_FallingAxonText> _items = [];
  final Random _random = Random();
  Size _screenSize = Size.zero;
  static const double _columnWidth = 65.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(days: 1),
    )..repeat();
  }

  void _initItems(Size size) {
    if (size == Size.zero || size == _screenSize) return;
    _screenSize = size;
    _items.clear();
    final int columnCount = (size.width / _columnWidth).floor();
    for (int i = 0; i < columnCount; i++) {
      final double xPos = (i * _columnWidth) + (_columnWidth / 2);
      _items.add(_FallingAxonText(x: xPos, random: _random, screenSize: size));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final newSize = constraints.biggest;
        if (newSize != _screenSize) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _initItems(newSize));
        }
        return CustomPaint(
          size: Size.infinite,
          painter: _HeyAxonRainPainter(
            items: _items,
            controller: _controller,
            speedFactor: 0.45,
          ),
        );
      },
    );
  }
}

class _HeyAxonRainPainter extends CustomPainter {
  final List<_FallingAxonText> items;
  final AnimationController controller;
  final double speedFactor;
  final TextPainter _textPainter = TextPainter(
    textDirection: TextDirection.rtl,
    textAlign: TextAlign.center,
  );

  _HeyAxonRainPainter({
    required this.items,
    required this.controller,
    required this.speedFactor,
  }) : super(repaint: controller);

  @override
  void paint(Canvas canvas, Size size) {
    for (final item in items) {
      item.update(speedFactor);
    }
    items.sort((a, b) => a.z.compareTo(b.z));

    for (final item in items) {
      _textPainter.text = TextSpan(
        text: item.label,
        style: TextStyle(
          fontFamily: kNastaliqFont,
          fontSize: item.fontSize,
          color: item.colorScheme.headColor.withAlpha(item.alpha),
          shadows: [
            Shadow(
              blurRadius: item.fontSize * 0.7,
              color: item.colorScheme.tailColor.withAlpha(item.alpha),
            ),
          ],
        ),
      );
      _textPainter.layout();
      canvas.save();
      canvas.translate(item.x, item.y);
      canvas.rotate(-pi / 2);
      _textPainter.paint(canvas, Offset(-(_textPainter.width / 2), 0));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _HeyAxonRainPainter oldDelegate) => false;
}