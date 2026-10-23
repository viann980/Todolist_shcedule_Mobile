import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:todolist_shcedule/services/schedule_api_service.dart';
import 'package:todolist_shcedule/widgets/schedule_form_sheet.dart';
import 'package:vibration/vibration.dart';

import 'models/schedule_item.dart';

void main() {
  runApp(const ScheduleApp());
}

class ScheduleApp extends StatelessWidget {
  const ScheduleApp({super.key, this.repository});

  final ScheduleRepository? repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Jadwal Kegiatan',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F4ED),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFF0F766E), width: 1.4),
          ),
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
      home: ScheduleHomePage(repository: repository ?? ScheduleApiService()),
    );
  }
}

class ScheduleHomePage extends StatefulWidget {
  const ScheduleHomePage({super.key, required this.repository});

  final ScheduleRepository repository;

  @override
  State<ScheduleHomePage> createState() => _ScheduleHomePageState();
}

class _ScheduleHomePageState extends State<ScheduleHomePage>
    with WidgetsBindingObserver {
  late final ScheduleRepository _repository;
  final Set<String> _alertedScheduleKeys = <String>{};

  List<ScheduleItem> _schedules = <ScheduleItem>[];
  ScheduleCategory? _selectedCategory;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  Timer? _scheduleWatcherTimer;
  Timer? _alarmStopTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _repository = widget.repository;
    _startScheduleWatcher();
    _loadSchedules();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scheduleWatcherTimer?.cancel();
    _stopActiveAlert();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkUpcomingSchedules();
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopActiveAlert();
    }
  }

  Future<void> _loadSchedules() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<ScheduleItem> schedules = await _repository.fetchSchedules();
      schedules.sort(_compareSchedules);
      _syncAlertedScheduleKeys(schedules);

      if (!mounted) {
        return;
      }

      setState(() {
        _schedules = schedules;
        _isLoading = false;
      });
      _checkUpcomingSchedules();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage =
        'Tidak bisa mengambil data jadwal. Cek API PHP dan MySQL.';
      });
    }
  }

  void _startScheduleWatcher() {
    _scheduleWatcherTimer?.cancel();
    _scheduleWatcherTimer = Timer.periodic(
      const Duration(seconds: 15),
          (Timer timer) => _checkUpcomingSchedules(),
    );
  }

  void _syncAlertedScheduleKeys(List<ScheduleItem> schedules) {
    final Set<String> validKeys =
    schedules.map((ScheduleItem item) => _alertKeyFor(item)).toSet();
    _alertedScheduleKeys.removeWhere((String key) => !validKeys.contains(key));
  }

  Future<void> _checkUpcomingSchedules() async {
    if (!mounted || _schedules.isEmpty) {
      return;
    }

    final DateTime now = DateTime.now();
    final List<ScheduleItem> upcomingSchedules = _schedules
        .where(
          (ScheduleItem item) =>
      !_alertedScheduleKeys.contains(_alertKeyFor(item)) &&
          isScheduleStartingSoon(item, now),
    )
        .toList();

    if (upcomingSchedules.isEmpty) {
      return;
    }

    for (final ScheduleItem item in upcomingSchedules) {
      _alertedScheduleKeys.add(_alertKeyFor(item));
    }

    await _triggerUpcomingScheduleAlert(
      upcomingSchedules.first,
      additionalCount: upcomingSchedules.length - 1,
    );
  }

  Future<void> _triggerUpcomingScheduleAlert(
      ScheduleItem item, {
        required int additionalCount,
      }) async {
    await _startDeviceAlert();

    if (!mounted) {
      return;
    }

    final String extraMessage = additionalCount > 0
        ? ' Ada $additionalCount jadwal lain yang juga segera dimulai.'
        : '';

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 20),
          content: Text(
            'Jadwal "${item.title}" dimulai kurang dari 1 menit lagi.$extraMessage',
          ),
          action: SnackBarAction(
            label: 'Matikan',
            onPressed: _stopActiveAlert,
          ),
        ),
      );
  }

  Future<void> _startDeviceAlert() async {
    _alarmStopTimer?.cancel();
    if (_supportsDeviceAlert) {
      final FlutterRingtonePlayer ringtonePlayer = FlutterRingtonePlayer();
      await ringtonePlayer.stop();
      await ringtonePlayer.playAlarm(
        asAlarm: true,
        looping: true,
        volume: 1.0,
      );

      final bool canVibrate = await Vibration.hasVibrator();
      if (canVibrate) {
        await Vibration.vibrate(pattern: <int>[0, 500, 250, 500, 250, 700]);
      }
    }

    _alarmStopTimer = Timer(const Duration(seconds: 20), _stopActiveAlert);
  }

  void _stopActiveAlert() {
    _alarmStopTimer?.cancel();
    _alarmStopTimer = null;
    if (_supportsDeviceAlert) {
      FlutterRingtonePlayer().stop();
      Vibration.cancel();
    }
  }

  String _alertKeyFor(ScheduleItem item) {
    return '${item.id}-${scheduleStartDateTime(item).toIso8601String()}';
  }

  bool get _supportsDeviceAlert {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> _openEditor([ScheduleItem? item]) async {
    final ScheduleDraft? draft = await showModalBottomSheet<ScheduleDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF5F0E6),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext context) {
        return ScheduleFormSheet(initialValue: item?.toDraft());
      },
    );

    if (draft == null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      if (item == null) {
        await _repository.createSchedule(draft);
      } else {
        await _repository.updateSchedule(item.id, draft);
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            item == null
                ? 'Jadwal berhasil ditambahkan.'
                : 'Jadwal berhasil diperbarui.',
          ),
        ),
      );
      await _loadSchedules();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menyimpan jadwal.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _deleteSchedule(ScheduleItem item) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Hapus jadwal'),
          content: Text('Yakin ingin menghapus "${item.title}"?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _repository.deleteSchedule(item.id);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jadwal berhasil dihapus.')),
      );
      await _loadSchedules();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menghapus jadwal.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<ScheduleItem> visibleSchedules = _visibleSchedules;
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jadwal Kegiatan'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: <Widget>[
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _isLoading ? null : _loadSchedules,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSaving ? null : _openEditor,
        backgroundColor: const Color(0xFF0F766E),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('Tambah jadwal'),
      ),
      body: Stack(
        children: <Widget>[
          RefreshIndicator(
            onRefresh: _loadSchedules,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
              children: <Widget>[
                _HeaderCard(
                  totalCount: _schedules.length,
                  workCount: _countByCategory(ScheduleCategory.kerja),
                  collegeCount: _countByCategory(ScheduleCategory.kuliah),
                  holidayCount: _countByCategory(ScheduleCategory.liburan),
                ),
                const SizedBox(height: 18),
                Text(
                  'Filter kategori',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    ChoiceChip(
                      label: const Text('Semua'),
                      selected: _selectedCategory == null,
                      onSelected: (_) {
                        setState(() {
                          _selectedCategory = null;
                        });
                      },
                    ),
                    ...ScheduleCategory.values.map(
                          (ScheduleCategory category) => ChoiceChip(
                        avatar: Icon(category.icon, size: 18),
                        label: Text(category.label),
                        selected: _selectedCategory == category,
                        onSelected: (_) {
                          setState(() {
                            _selectedCategory = category;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                if (_errorMessage != null) ...<Widget>[
                  const SizedBox(height: 18),
                  _InfoBanner(
                    icon: Icons.cloud_off_rounded,
                    title: 'Koneksi API bermasalah',
                    message: _errorMessage!,
                    actionLabel: 'Coba lagi',
                    onAction: _loadSchedules,
                  ),
                ],
                const SizedBox(height: 18),
                Text(
                  'Daftar jadwal',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (visibleSchedules.isEmpty)
                  _EmptyStateCard(
                    hasFilter: _selectedCategory != null,
                    onAdd: _openEditor,
                  )
                else
                  ...visibleSchedules.map(
                        (ScheduleItem item) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _ScheduleCard(
                        item: item,
                        onEdit: () => _openEditor(item),
                        onDelete: () => _deleteSchedule(item),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_isSaving)
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: LinearProgressIndicator(minHeight: 3),
            ),
        ],
      ),
    );
  }

  List<ScheduleItem> get _visibleSchedules {
    if (_selectedCategory == null) {
      return List<ScheduleItem>.from(_schedules);
    }

    return _schedules
        .where((ScheduleItem item) => item.category == _selectedCategory)
        .toList();
  }

  int _countByCategory(ScheduleCategory category) {
    return _schedules
        .where((ScheduleItem item) => item.category == category)
        .length;
  }

  int _compareSchedules(ScheduleItem first, ScheduleItem second) {
    final int dateComparison = first.date.compareTo(second.date);
    if (dateComparison != 0) {
      return dateComparison;
    }

    return first.startTime.compareTo(second.startTime);
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.totalCount,
    required this.workCount,
    required this.collegeCount,
    required this.holidayCount,
  });

  final int totalCount;
  final int workCount;
  final int collegeCount;
  final int holidayCount;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFF115E59),
            Color(0xFF0F766E),
            Color(0xFF1D4ED8)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x25115E59),
            blurRadius: 28,
            offset: Offset(0, 18),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Agenda lebih rapi',
            style: textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Kelola jadwal kerja, kuliah, dan liburan dalam satu dashboard sederhana.',
            style: textTheme.bodyMedium?.copyWith(
              color: _withAlpha(Colors.white, 0.9),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _withAlpha(Colors.white, 0.12),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _withAlpha(Colors.white, 0.16)),
            ),
            child: Row(
              children: <Widget>[
                const Icon(Icons.event_note_rounded,
                    color: Colors.white, size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '$totalCount jadwal tersimpan',
                        style: textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Tarik ke bawah untuk menyegarkan data dari API.',
                        style: textTheme.bodySmall?.copyWith(
                          color: _withAlpha(Colors.white, 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: _MetricCard(
                  label: 'Kerja',
                  value: workCount,
                  color: ScheduleCategory.kerja.color,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  label: 'Kuliah',
                  value: collegeCount,
                  color: ScheduleCategory.kuliah.color,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  label: 'Liburan',
                  value: holidayCount,
                  color: ScheduleCategory.liburan.color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: _withAlpha(Colors.white, 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(height: 10),
          Text(
            '$value',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: _withAlpha(Colors.white, 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(message),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: onAction,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(actionLabel),
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

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({required this.hasFilter, required this.onAdd});

  final bool hasFilter;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: <Widget>[
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFE2F3F0),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.calendar_month_outlined,
                color: Color(0xFF0F766E),
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              hasFilter
                  ? 'Belum ada jadwal di kategori ini.'
                  : 'Belum ada jadwal tersimpan.',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hasFilter
                  ? 'Pilih kategori lain atau tambahkan jadwal baru.'
                  : 'Mulai tambahkan agenda kerja, kuliah, atau liburan Anda.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_circle_outline_rounded),
              label: const Text('Tambah jadwal pertama'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  final ScheduleItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final Color categoryColor = item.category.color;

    return Card(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _withAlpha(categoryColor, 0.16)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _withAlpha(categoryColor, 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(item.category.icon, color: categoryColor),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _withAlpha(categoryColor, 0.10),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            item.category.label,
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                              color: categoryColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          item.title,
                          style:
                          Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (String value) {
                      if (value == 'edit') {
                        onEdit();
                      } else {
                        onDelete();
                      }
                    },
                    itemBuilder: (BuildContext context) =>
                    <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                        value: 'edit',
                        child: Text('Edit'),
                      ),
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Text('Hapus'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  _DetailBadge(
                    icon: Icons.calendar_today_outlined,
                    label: item.dateLabel,
                  ),
                  _DetailBadge(
                    icon: Icons.schedule_outlined,
                    label: item.timeRangeLabel,
                  ),
                  if (item.location.trim().isNotEmpty)
                    _DetailBadge(
                      icon: Icons.location_on_outlined,
                      label: item.location,
                    ),
                ],
              ),
              if (item.notes.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 14),
                Text(
                  item.notes,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(height: 1.5),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailBadge extends StatelessWidget {
  const _DetailBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F4EE),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 18, color: const Color(0xFF5B6475)),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

Color _withAlpha(Color color, double opacity) {
  final int alpha = (opacity * 255).round().clamp(0, 255);
  // ignore: deprecated_member_use
  return Color.fromARGB(alpha, color.red, color.green, color.blue);
}

DateTime scheduleStartDateTime(ScheduleItem item) {
  final List<String> parts = normalizeTime(item.startTime).split(':');
  final int hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
  final int minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  final int second = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;

  return DateTime(
    item.date.year,
    item.date.month,
    item.date.day,
    hour,
    minute,
    second,
  );
}

bool isScheduleStartingSoon(
    ScheduleItem item,
    DateTime now, {
      Duration window = const Duration(minutes: 1),
    }) {
  final Duration difference = scheduleStartDateTime(item).difference(now);
  return !difference.isNegative && difference <= window;
}
