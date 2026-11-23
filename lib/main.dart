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
const int kSessionSchemaVersion = 2;

String toPersianDigits(Object input) {
  const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
  var text = input.toString();
  for (int i = 0; i < english.length; i++) {
    text = text.replaceAll(english[i], persian[i]);
  }
  return text;
}

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
  final String phrase;
  final String desc;
  final bool isNegative;

  const PromptItem({
    required this.category,
    required this.slug,
    required this.title,
    required this.phrase,
    required this.desc,
    this.isNegative = false,
  });
}

const List<PromptItem> kPrompts = [
  PromptItem(category: 'لحن عادی', slug: 'normal_01', title: '۱. عادی و طبیعی', phrase: 'هی آکسون', desc: 'خیلی معمولی و روزمره بگو'),
  PromptItem(category: 'سرعت بالا', slug: 'fast_01', title: '۲. سریع و خودمونی', phrase: 'هی آکسون', desc: 'کمی تندتر و محاوره‌ای بگو'),
  PromptItem(category: 'صدای آرام', slug: 'quiet_01', title: '۳. آروم و یواش', phrase: 'هی آکسون', desc: 'با صدای آروم بگو'),
  PromptItem(category: 'صدای بلند', slug: 'loud_01', title: '۴. بلند و رسا', phrase: 'هی آکسون', desc: 'با صدای بلند و واضح بگو'),
  PromptItem(category: 'تنوع لحن', slug: 'question_01', title: '۵. لحن پرسشی', phrase: 'هی آکسون؟', desc: 'انگار سوال می‌پرسی بگو'),
  PromptItem(category: 'سناریو واقعی', slug: 'before_cmd', title: '۶. قبل از دستور', phrase: 'هی آکسون', desc: 'انگار می‌خوای کاری بهش بسپاری بگو'),
  PromptItem(category: 'لحن عادی', slug: 'normal_02', title: '۷. عادی (تکرار دوم)', phrase: 'هی آکسون', desc: 'دوباره معمولی و طبیعی بگو'),
  PromptItem(category: 'سرعت بالا', slug: 'very_fast', title: '۸. خیلی سریع و سرهم', phrase: 'هی‌آکسون', desc: 'پشت سر هم و سریع بگو'),
  PromptItem(category: 'صدای آرام', slug: 'whisper_01', title: '۹. نجوا / نصف شب', phrase: 'هی آکسون', desc: 'خیلی یواش و نزدیک میکروفون بگو'),
  PromptItem(category: 'صدای بلند', slug: 'energetic_01', title: '۱۰. پرانرژی و محکم', phrase: 'هی آکسون!', desc: 'خیلی پرانرژی و محکم بگو'),
  PromptItem(category: 'تنوع لحن', slug: 'tired_stretched', title: '۱۱. خسته و کشیده', phrase: 'هِــی آکسون', desc: 'با لحن خسته و ریلکس بگو'),
  PromptItem(category: 'سناریو واقعی', slug: 'short_pause', title: '۱۲. با مکث کوتاه وسطش', phrase: 'هی... آکسون', desc: 'با نیم ثانیه مکث بین دو کلمه بگو'),
  PromptItem(category: 'لحن عادی', slug: 'normal_03', title: '۱۳. عادی (تکرار سوم)', phrase: 'هی آکسون', desc: 'یک بار دیگر معمولی بگو'),
  PromptItem(category: 'صدای بلند', slug: 'far_2m_01', title: '۱۴. فاصله ۱.۵ تا ۲ متری', phrase: 'هی آکسون', desc: 'کمی از سیستم فاصله بگیر و صداش بزن'),
  PromptItem(category: 'تنوع لحن', slug: 'friendly_smile', title: '۱۵. خوشحال و صمیمی', phrase: 'هی آکسون', desc: 'با لبخند و لحن صمیمی بگو'),
  PromptItem(category: 'سرعت بالا', slug: 'hurried', title: '۱۶. عجله‌ای', phrase: 'هی آکسون!', desc: 'انگار عجله داری بگو'),
  PromptItem(category: 'صدای آرام', slug: 'soft_clear', title: '۱۷. ملایم و شمرده', phrase: 'هی آکسون', desc: 'آروم و کاملاً شمرده بگو'),
  PromptItem(category: 'سناریو واقعی', slug: 'turned_right', title: '۱۸. چرخیده به سمت راست', phrase: 'هی آکسون', desc: 'سرت رو بچرخون سمت راست و بگو'),
  PromptItem(category: 'لحن عادی', slug: 'normal_04', title: '۱۹. عادی (تکرار چهارم)', phrase: 'هی آکسون', desc: 'معمولی و روان بگو'),
  PromptItem(category: 'تنوع لحن', slug: 'serious_cmd', title: '۲۰. جدی و دستوری', phrase: 'هی آکسون', desc: 'با لحن جدی و قاطع بگو'),
  PromptItem(category: 'سرعت بالا', slug: 'fast_short', title: '۲۱. سریع و کوتاه', phrase: 'هی آکسون', desc: 'خیلی سریع و بریده بگو'),
  PromptItem(category: 'صدای بلند', slug: 'loud_02', title: '۲۲. بلند (تکرار دوم)', phrase: 'هی آکسون', desc: 'دوباره با صدای بلند بگو'),
  PromptItem(category: 'صدای آرام', slug: 'morning_voice', title: '۲۳. صدای صبحگاهی', phrase: 'هی آکسون', desc: 'انگار تازه بیدار شدی و صدات بم‌تره'),
  PromptItem(category: 'سناریو واقعی', slug: 'turned_left', title: '۲۴. چرخیده به سمت چپ', phrase: 'هی آکسون', desc: 'سرت رو بچرخون سمت چپ و بگو'),
  PromptItem(category: 'لحن عادی', slug: 'normal_05', title: '۲۵. عادی (تکرار پنجم)', phrase: 'هی آکسون', desc: 'دوباره عادی بگو'),
  PromptItem(category: 'تنوع لحن', slug: 'question_02', title: '۲۶. لحن پرسشی (تکرار)', phrase: 'هی آکسون؟', desc: 'دوباره با لحن سوالی بگو'),
  PromptItem(category: 'سناریو واقعی', slug: 'leaned_back', title: '۲۷. تکیه داده به صندلی', phrase: 'هی آکسون', desc: 'کاملاً لم بده عقب و بگو'),
  PromptItem(category: 'سرعت بالا', slug: 'busy_fast', title: '۲۸. وسط کار با عجله', phrase: 'هی آکسون', desc: 'انگار سرت شلوغه و حواست جای دیگه‌ست'),
  PromptItem(category: 'صدای آرام', slug: 'quiet_02', title: '۲۹. آروم (تکرار دوم)', phrase: 'هی آکسون', desc: 'دوباره با صدای آروم بگو'),
  PromptItem(category: 'صدای بلند', slug: 'energetic_02', title: '۳۰. پرانرژی (تکرار دوم)', phrase: 'هی آکسون!', desc: 'دوباره با انرژی بالا بگو'),
  PromptItem(category: 'لحن عادی', slug: 'normal_06', title: '۳۱. عادی (تکرار ششم)', phrase: 'هی آکسون', desc: 'با ریتم طبیعی خودت بگو'),
  PromptItem(category: 'تنوع لحن', slug: 'stretch_axon', title: '۳۲. کشیده روی آکسون', phrase: 'هی آکســـون', desc: 'بخش دوم رو کمی بکش'),
  PromptItem(category: 'سناریو واقعی', slug: 'looking_down', title: '۳۳. رو به پایین', phrase: 'هی آکسون', desc: 'سرت رو پایین بگیر (مثل نگاه به گوشی) و بگو'),
  PromptItem(category: 'تنوع لحن', slug: 'annoyed_frown', title: '۳۴. کلافه یا اخمو', phrase: 'هی آکسون', desc: 'با لحن کمی کلافه یا اخمو بگو'),
  PromptItem(category: 'صدای آرام', slug: 'whisper_02', title: '۳۵. نجوا (تکرار دوم)', phrase: 'هی آکسون', desc: 'دوباره خیلی یواش و نزدیک بگو'),
  PromptItem(category: 'صدای بلند', slug: 'far_2m_02', title: '۳۶. صدا زدن از دور (تکرار)', phrase: 'هی آکسون', desc: 'از دور و با صدای بلند بگو'),
  PromptItem(category: 'تنوع لحن', slug: 'stretch_hey', title: '۳۷. کشیده روی هی', phrase: 'هِـــی آکسون', desc: 'کلمه «هی» رو کمی کشیده بگو'),
  PromptItem(category: 'سناریو واقعی', slug: 'close_mic', title: '۳۸. خیلی نزدیک به میکروفون', phrase: 'هی آکسون', desc: 'خیلی نزدیک میکروفون بگو'),
  PromptItem(category: 'سناریو واقعی', slug: 'walking_room', title: '۳۹. در حال حرکت در اتاق', phrase: 'هی آکسون', desc: 'حین کمی حرکت کردن بگو'),
  PromptItem(category: 'محیط پرنویز', slug: 'noisy_music_01', title: '۴۰. با صدای موزیک یا ویدیو', phrase: 'هی آکسون', desc: 'یه آهنگ/ویدیو پخش کن و همزمان بگو'),
  PromptItem(category: 'محیط پرنویز', slug: 'noisy_typing', title: '۴۱. همراه با تایپ کیبورد', phrase: 'هی آکسون', desc: 'حین زدن دکمه‌های کیبورد بگو'),
  PromptItem(category: 'محیط پرنویز', slug: 'noisy_loud', title: '۴۲. آخرین بار به دلخواه!', phrase: 'هی آکسون', desc: 'هر طور راحت‌تری (ترجیحاً با نویز محیط) بگو'),
  PromptItem(
    category: 'کلمه مشابه (منفی)',
    slug: 'neg_axon_only_01',
    title: '۴۳. فقط «آکسون» خالی',
    phrase: 'آکسون',
    desc: 'بدون کلمه «هی»، فقط معمولی بگو آکسون',
    isNegative: true,
  ),
  PromptItem(
    category: 'کلمه مشابه (منفی)',
    slug: 'neg_axon_only_02',
    title: '۴۴. «آکسون» خالی (تکرار)',
    phrase: 'آکسون',
    desc: 'دوباره بدون «هی»، کمی سریع یا بلندتر بگو',
    isNegative: true,
  ),
  PromptItem(
    category: 'کلمه مشابه (منفی)',
    slug: 'neg_vaksan',
    title: '۴۵. کلمه مشابه: واکسن',
    phrase: 'هی واکسن',
    desc: 'طبیعی بگو: «هی واکسن» (یا فقط واکسن)',
    isNegative: true,
  ),
  PromptItem(
    category: 'کلمه مشابه (منفی)',
    slug: 'neg_ehsan',
    title: '۴۶. کلمه مشابه: هی احسان',
    phrase: 'هی احسان',
    desc: 'انگار دوستت رو صدا می‌زنی بگو',
    isNegative: true,
  ),
  PromptItem(
    category: 'کلمه مشابه (منفی)',
    slug: 'neg_asan',
    title: '۴۷. کلمه مشابه: خیلی آسون',
    phrase: 'خیلی آسون',
    desc: 'معمولی و روان بگو',
    isNegative: true,
  ),
  PromptItem(
    category: 'کلمه مشابه (منفی)',
    slug: 'neg_aks_oon',
    title: '۴۸. کلمه مشابه: هی عکسِ اون',
    phrase: 'هی عکسِ اون',
    desc: 'محاوره‌ای و معمولی بگو',
    isNegative: true,
  ),
  PromptItem(
    category: 'کلمه مشابه (منفی)',
    slug: 'neg_oxford',
    title: '۴۹. کلمه مشابه: آکسفورد',
    phrase: 'آکسفورد',
    desc: 'معمولی بگو',
    isNegative: true,
  ),
  PromptItem(
    category: 'کلمه مشابه (منفی)',
    slug: 'neg_hey_agha',
    title: '۵۰. کلمه مشابه: هی آقا',
    phrase: 'هی آقا',
    desc: 'معمولی و روزمره بگو',
    isNegative: true,
  ),
  PromptItem(
    category: 'کلمه مشابه (منفی)',
    slug: 'neg_hey_hasti',
    title: '۵۱. کلمه مشابه: هی هستی؟',
    phrase: 'هی هستی؟',
    desc: 'با لحن پرسشی بگو',
    isNegative: true,
  ),
  PromptItem(
    category: 'کلمه مشابه (منفی)',
    slug: 'neg_asansor',
    title: '۵۲. کلمه مشابه: آسانسور',
    phrase: 'آسانسور',
    desc: 'معمولی بگو',
    isNegative: true,
  ),
  PromptItem(
    category: 'کلمه مشابه (منفی)',
    slug: 'neg_hey_salam',
    title: '۵۳. کلمه مشابه: هی سلام',
    phrase: 'هی سلام',
    desc: 'صمیمی و معمولی بگو',
    isNegative: true,
  ),
  PromptItem(
    category: 'گفتار عادی (منفی)',
    slug: 'neg_normal_speech',
    title: '۵۴. یک جمله معمولی فارسی',
    phrase: 'امروز هوا چطوره؟',
    desc: 'این جمله (یا هر جمله کوتاه دیگه‌ای) رو معمولی بگو',
    isNegative: true,
  ),
  PromptItem(
    category: 'نویز پس‌زمینه (منفی)',
    slug: 'neg_room_silence',
    title: '۵۵. سکوت و صدای اتاق',
    phrase: '🤫 ۲ ثانیه هیچی نگو',
    desc: 'ضبط رو بزن، ۲ ثانیه سکوت کن تا صدای عادی میکروفونت ثبت شه و بعد متوقف کن',
    isNegative: true,
  ),
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
  bool _isBusy = false;
  bool _isLoading = true;
  double _amplitude = 0.0;
  Timer? _ampTimer;
  Timer? _maxDurationTimer;
  DateTime? _lastToggleAt;
  DateTime? _recordStartAt;

  String _userName = 'speaker';
  String _gender = 'unspecified';
  String _micType = 'laptop';
  String _statusText = 'روی دکمه بزن (یا Space) و عبارت بالا رو بگو';
  String _zipPath = '';

  Directory? _sessionDir;
  File? _stateFile;
  final List<String?> _recordedPaths = List.filled(kPrompts.length, null);

  bool _hasSavedSession = false;
  String _savedUserName = '';
  String _savedGender = 'unspecified';
  String _savedMicType = 'laptop';
  int _savedStep = 0;
  List<String?> _savedPaths = List.filled(kPrompts.length, null);

  @override
  void initState() {
    super.initState();
    _initStorageAndCheckResume();
  }

  @override
  void dispose() {
    _maxDurationTimer?.cancel();
    _ampTimer?.cancel();
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
        final schemaVersion = (data['schemaVersion'] as int?) ?? 1;
        final user = (data['userName'] as String?) ?? 'speaker';
        final completed = (data['completed'] as bool?) ?? false;
        final savedZip = (data['zipPath'] as String?) ?? '';

        if (completed && savedZip.isNotEmpty && await File(savedZip).exists()) {
          _userName = user;
          _zipPath = savedZip;
          _screen = 2;
        } else if (schemaVersion == kSessionSchemaVersion) {
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
            _savedGender = (data['gender'] as String?) ?? 'unspecified';
            _savedMicType = (data['micType'] as String?) ?? 'laptop';
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
      'schemaVersion': kSessionSchemaVersion,
      'userName': _userName,
      'gender': _gender,
      'micType': _micType,
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
    if (_isRecording || _isBusy) return;
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
      _statusText = 'روی دکمه بزن (یا Space) و عبارت بالا رو بگو';
    });
    _focusNode.requestFocus();
  }

  Future<void> _resumeSavedSession() async {
    if (!await _ensureMicPermission()) return;

    _userName = _savedUserName;
    _gender = _savedGender;
    _micType = _savedMicType;
    for (int i = 0; i < kPrompts.length; i++) {
      _recordedPaths[i] = _savedPaths[i];
    }

    setState(() {
      _screen = 1;
      _step = _savedStep;
      _amplitude = 0.0;
      _statusText = 'ادامه ضبط از مرحله ${toPersianDigits(_savedStep + 1)}...';
    });
    _focusNode.requestFocus();
  }

  double _mapAmplitude(double db) {
    if (!db.isFinite || db <= -65.0) return 0.0;
    final norm = ((db + 65.0) / 55.0).clamp(0.0, 1.0);
    return pow(norm, 0.85).toDouble();
  }

  Future<void> _toggleRecord({bool forceAutoStop = false}) async {
    if (_isBusy) return;

    final now = DateTime.now();
    if (!forceAutoStop &&
        _lastToggleAt != null &&
        now.difference(_lastToggleAt!).inMilliseconds < 320) {
      return;
    }
    _lastToggleAt = now;
    _isBusy = true;

    try {
      if (!_isRecording) {
        final prompt = kPrompts[_step];
        final stepStr = (_step + 1).toString().padLeft(2, '0');
        final prefix = prompt.isNegative ? 'neg' : 'pos';
        final fileName = '${_userName}_${prefix}_${stepStr}_${prompt.slug}.wav';
        final path = '${_sessionDir!.path}/$fileName';

        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: 16000,
            numChannels: 1,
          ),
          path: path,
        );

        _recordStartAt = DateTime.now();

        if (mounted) {
          setState(() {
            _isRecording = true;
            _amplitude = 0.0;
            _statusText = prompt.slug == 'neg_room_silence'
                ? '● در حال ضبط صدای اتاق... ${toPersianDigits(2)} ثانیه سکوت کن و دوباره بزن'
                : '● در حال ضبط... بگو «${prompt.phrase}» و دوباره بزن';
          });
        }

        _maxDurationTimer?.cancel();
        _maxDurationTimer = Timer(const Duration(seconds: 4), () {
          if (mounted && _isRecording) {
            _toggleRecord(forceAutoStop: true);
          }
        });

        _ampTimer?.cancel();
        _ampTimer = Timer.periodic(const Duration(milliseconds: 50), (_) async {
          if (!mounted || !_isRecording) return;
          try {
            final amp = await _recorder.getAmplitude();
            if (!mounted || !_isRecording) return;
            setState(() {
              _amplitude = _mapAmplitude(amp.current);
            });
          } catch (_) {}
        });
      } else {
        _maxDurationTimer?.cancel();
        _maxDurationTimer = null;
        _ampTimer?.cancel();
        _ampTimer = null;

        final durationMs = _recordStartAt != null
            ? DateTime.now().difference(_recordStartAt!).inMilliseconds
            : 1000;
        final path = await _recorder.stop();

        if (mounted) {
          setState(() {
            _isRecording = false;
            _amplitude = 0.0;
          });
        }

        if (path != null) {
          if (durationMs < 350) {
            final f = File(path);
            if (await f.exists()) await f.delete();
            if (mounted) {
              setState(() {
                _statusText = '⚠️ ضبط خیلی کوتاه بود! دوباره بزن، کامل بگو و بعد متوقف کن.';
              });
            }
          } else {
            _recordedPaths[_step] = path;
            if (_step + 1 >= kPrompts.length) {
              await _createZipAndFinish();
            } else {
              if (mounted) {
                setState(() {
                  _step++;
                  _statusText = forceAutoStop
                      ? '✓ خودکار متوقف و ذخیره شد! آماده مرحله بعد.'
                      : '✓ ذخیره شد!';
                });
              }
              await _saveProgress();
            }
          }
        }
      }
    } finally {
      _isBusy = false;
    }
  }

  Future<void> _prevStep() async {
    if (_isRecording || _isBusy || _step == 0) return;
    setState(() {
      _step--;
      _statusText = 'برگشتی به مرحله قبل؛ دوباره ضبط کن';
    });
    await _saveProgress();
  }

  Future<void> _createZipAndFinish() async {
    final archive = Archive();
    int posCount = 0;
    int negCount = 0;

    for (int i = 0; i < kPrompts.length; i++) {
      final path = _recordedPaths[i];
      if (path == null) continue;
      final file = File(path);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final fileName = file.uri.pathSegments.last;
        final isNeg = kPrompts[i].isNegative;
        final folder = isNeg ? 'negative' : 'positive';
        if (isNeg) {
          negCount++;
        } else {
          posCount++;
        }
        archive.addFile(ArchiveFile('$folder/$fileName', bytes.length, bytes));
      }
    }

    final metadata = {
      'userName': _userName,
      'gender': _gender,
      'micType': _micType,
      'platform': Platform.operatingSystem,
      'sampleRate': 16000,
      'channels': 1,
      'format': 'wav_pcm16',
      'positiveCount': posCount,
      'negativeCount': negCount,
      'totalCount': posCount + negCount,
      'createdAt': DateTime.now().toIso8601String(),
    };
    final metaBytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(metadata));
    archive.addFile(ArchiveFile('metadata.json', metaBytes.length, metaBytes));

    final zipBytes = ZipEncoder().encode(archive);
    final outDir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    final outFile = File('${outDir.path}${Platform.pathSeparator}axon_voices_$_userName.zip');
    await outFile.writeAsBytes(zipBytes!);

    if (_sessionDir != null && await _sessionDir!.exists()) {
      await for (final entity in _sessionDir!.list()) {
        if (entity is File && entity.path.endsWith('.wav')) {
          await entity.delete();
        }
      }
    }

    await _saveProgress(completed: true, zipPath: outFile.path);

    if (mounted) {
      setState(() {
        _zipPath = outFile.path;
        _screen = 2;
      });
    }
  }

  Future<void> _openZipFolder() async {
    if (_zipPath.isEmpty) return;
    try {
      if (Platform.isWindows) {
        final winPath = _zipPath.replaceAll('/', '\\');
        await Process.start(
          'explorer.exe',
          ['/select,', winPath],
          mode: ProcessStartMode.detached,
        );
      } else if (Platform.isMacOS) {
        await Process.start(
          'open',
          ['-R', _zipPath],
          mode: ProcessStartMode.detached,
        );
      } else if (Platform.isLinux) {
        await Process.start(
          'xdg-open',
          [File(_zipPath).parent.path],
          mode: ProcessStartMode.detached,
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('امکان باز کردن پوشه نبود؛ فایل در پوشه Downloads ذخیره شده است.')),
        );
      }
    }
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    width: 470,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: const Color(0xFF181926).withAlpha(224),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: (_screen == 1 && kPrompts[_step].isNegative
                                ? const Color(0xFFFAB387)
                                : const Color(0xFF89B4FA))
                            .withAlpha(75),
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
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF89B4FA).withAlpha(45)
                : const Color(0xFF24273A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? const Color(0xFF89B4FA) : const Color(0xFF363A4F),
              width: 1.1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            toPersianDigits(label),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              color: selected ? const Color(0xFF89B4FA) : const Color(0xFFA6ADC8),
            ),
          ),
        ),
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
          child: const Icon(Icons.mic_rounded, size: 34, color: Color(0xFF89B4FA)),
        ),
        const SizedBox(height: 12),
        const Text(
          'ضبط صدای «هی آکسون»',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFF9E2AF)),
        ),
        const SizedBox(height: 8),
        Text(
          toPersianDigits(
            '${kPrompts.length} مرحله کوتاه داریم (۴۲ بار «هی آکسون» + ۱۳ کلمه مشابه).\nهر زمان خسته شدی برنامه رو ببند؛ سری بعد از ادامه‌اش میره!',
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: Color(0xFFBAC2DE), height: 1.65),
        ),
        if (_hasSavedSession) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFA6E3A1).withAlpha(22),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFA6E3A1).withAlpha(90)),
            ),
            child: Column(
              children: [
                Text(
                  'یک ضبط ناتمام برای «$_savedUserName» وجود دارد (مرحله ${toPersianDigits(_savedStep + 1)} از ${toPersianDigits(kPrompts.length)})',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFFA6E3A1), fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton.icon(
                    onPressed: _resumeSavedSession,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(
                      'ادامه از مرحله ${toPersianDigits(_savedStep + 1)}',
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
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
          const SizedBox(height: 12),
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
            hintText: 'اسمت (انگلیسی، مثلاً Pouya)',
            hintStyle: const TextStyle(color: Color(0xFF6C7086)),
            filled: true,
            fillColor: const Color(0xFF24273A),
            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildChoiceChip(
              label: 'آقا',
              selected: _gender == 'male',
              onTap: () => setState(() => _gender = 'male'),
            ),
            const SizedBox(width: 8),
            _buildChoiceChip(
              label: 'خانم',
              selected: _gender == 'female',
              onTap: () => setState(() => _gender = 'female'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildChoiceChip(
              label: 'میکروفون لپ‌تاپ',
              selected: _micType == 'laptop',
              onTap: () => setState(() => _micType = 'laptop'),
            ),
            const SizedBox(width: 8),
            _buildChoiceChip(
              label: 'هدست / هندزفری',
              selected: _micType == 'headset',
              onTap: () => setState(() => _micType = 'headset'),
            ),
          ],
        ),
        const SizedBox(height: 16),
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
    final accentColor = prompt.isNegative ? const Color(0xFFFAB387) : const Color(0xFF89B4FA);

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
                  color: accentColor.withAlpha(35),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  toPersianDigits(prompt.category),
                  style: TextStyle(fontSize: 12, color: accentColor, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                'مرحله ${toPersianDigits(_step + 1)} از ${toPersianDigits(kPrompts.length)}',
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
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            toPersianDigits(prompt.title),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: prompt.isNegative ? const Color(0xFFFAB387) : const Color(0xFFF9E2AF),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            decoration: BoxDecoration(
              color: accentColor.withAlpha(24),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accentColor.withAlpha(85)),
            ),
            child: Text(
              toPersianDigits(prompt.phrase),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            toPersianDigits(prompt.desc),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13.5, color: Color(0xFFCDD6F4), height: 1.5),
          ),
          if (prompt.isNegative) ...[
            const SizedBox(height: 4),
            const Text(
              'این مرحله برای جلوگیری از بیدار شدن اشتباهی مدل روی کلمات مشابهه',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: Color(0xFFFAB387)),
            ),
          ],
          const SizedBox(height: 12),
          SiriOrbVisualizer(
            isRecording: _isRecording,
            amplitude: _amplitude,
            onTap: () => _toggleRecord(),
          ),
          const SizedBox(height: 12),
          ExcludeFocus(
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: () => _toggleRecord(),
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
                const SizedBox(height: 12),
                Text(
                  toPersianDigits(_statusText),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: _isRecording ? const Color(0xFFF38BA8) : const Color(0xFF9399B2),
                  ),
                ),
                const SizedBox(height: 10),
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
        const SizedBox(height: 12),
        const Text(
          'دمت گرم! تمام شد 🎉',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFA6E3A1)),
        ),
        const SizedBox(height: 8),
        Text(
          'فایل زیپ ${toPersianDigits(kPrompts.length)} صدا در مسیر زیر ذخیره شد. همینو توی تلگرام برام بفرست:',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: Color(0xFFBAC2DE), height: 1.6),
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
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton.icon(
            onPressed: _openZipFolder,
            icon: const Icon(Icons.folder_open_rounded, size: 19),
            label: const Text('باز کردن پوشه فایل زیپ', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFA6E3A1),
              foregroundColor: const Color(0xFF11111B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 46,
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
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF24A1DE),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: _resetToStartScreen,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('شروع ضبط جدید'),
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
        final speed = widget.isRecording ? (0.85 + _smoothAmp * 4.2) : 0.65;
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
          width: 126,
          height: 126,
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
    final idlePulse = isRecording
        ? (sin(time * 2.4) * 2.5)
        : (sin(time * 1.8) * 2.0);
    final baseR = (size.width * 0.25) + (voice * 17.5) + idlePulse;

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

    final wobbleStrength = isRecording ? (3.2 + voice * 17.5) : 2.2;
    final orbitDist = isRecording ? (2.4 + voice * 9.0) : 1.8;
    final activeMix = isRecording ? (0.45 + voice * 0.55) : 0.35;

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