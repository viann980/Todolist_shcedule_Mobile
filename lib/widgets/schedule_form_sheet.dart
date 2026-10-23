import 'package:flutter/material.dart';

import '../models/schedule_item.dart';

class ScheduleFormSheet extends StatefulWidget {
  const ScheduleFormSheet({super.key, this.initialValue});

  final ScheduleDraft? initialValue;

  @override
  State<ScheduleFormSheet> createState() => _ScheduleFormSheetState();
}

class _ScheduleFormSheetState extends State<ScheduleFormSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _locationController;
  late final TextEditingController _notesController;

  late ScheduleCategory _selectedCategory;
  late DateTime _selectedDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;

  @override
  void initState() {
    super.initState();

    final ScheduleDraft initialValue = widget.initialValue ??
        ScheduleDraft(
          title: '',
          category: ScheduleCategory.kerja,
          date: DateTime.now(),
          startTime: '08:00:00',
          endTime: '09:00:00',
          location: '',
          notes: '',
        );

    _titleController = TextEditingController(text: initialValue.title);
    _locationController = TextEditingController(text: initialValue.location);
    _notesController = TextEditingController(text: initialValue.notes);

    _selectedCategory = initialValue.category;
    _selectedDate = DateTime(
      initialValue.date.year,
      initialValue.date.month,
      initialValue.date.day,
    );
    _startTime = _parseTime(initialValue.startTime);
    _endTime = _parseTime(initialValue.endTime);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.initialValue != null;
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 160),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isEditing ? 'Edit jadwal' : 'Tambah jadwal',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  'Catat kegiatan kerja, kuliah, atau liburan dalam satu tempat.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _titleController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Judul kegiatan',
                    hintText: 'Contoh: Rapat mingguan tim',
                  ),
                  validator: (String? value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Judul wajib diisi.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<ScheduleCategory>(
                  // ignore: deprecated_member_use
                  value: _selectedCategory,
                  decoration: const InputDecoration(labelText: 'Kategori'),
                  items: ScheduleCategory.values
                      .map(
                        (ScheduleCategory category) =>
                        DropdownMenuItem<ScheduleCategory>(
                          value: category,
                          child: Text(category.label),
                        ),
                  )
                      .toList(),
                  onChanged: (ScheduleCategory? value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _selectedCategory = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    if (constraints.maxWidth < 560) {
                      return Column(
                        children: <Widget>[
                          _PickerField(
                            label: 'Tanggal',
                            value: formatDateLabel(_selectedDate),
                            icon: Icons.calendar_today_outlined,
                            onTap: _pickDate,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: _PickerField(
                                  label: 'Mulai',
                                  value: _formatTimeOfDay(_startTime),
                                  icon: Icons.access_time_outlined,
                                  onTap: () => _pickTime(isStartTime: true),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _PickerField(
                                  label: 'Selesai',
                                  value: _formatTimeOfDay(_endTime),
                                  icon: Icons.timer_outlined,
                                  onTap: () => _pickTime(isStartTime: false),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: <Widget>[
                        Expanded(
                          child: _PickerField(
                            label: 'Tanggal',
                            value: formatDateLabel(_selectedDate),
                            icon: Icons.calendar_today_outlined,
                            onTap: _pickDate,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PickerField(
                            label: 'Mulai',
                            value: _formatTimeOfDay(_startTime),
                            icon: Icons.access_time_outlined,
                            onTap: () => _pickTime(isStartTime: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PickerField(
                            label: 'Selesai',
                            value: _formatTimeOfDay(_endTime),
                            icon: Icons.timer_outlined,
                            onTap: () => _pickTime(isStartTime: false),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _locationController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Lokasi',
                    hintText: 'Contoh: Kampus A, Zoom, Bali',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Catatan',
                    hintText: 'Tambahkan detail penting jika perlu.',
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(isEditing ? 'Simpan perubahan' : 'Simpan jadwal'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );

    if (pickedDate == null) {
      return;
    }

    setState(() {
      _selectedDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
      );
    });
  }

  Future<void> _pickTime({required bool isStartTime}) async {
    final TimeOfDay currentValue = isStartTime ? _startTime : _endTime;
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: currentValue,
    );

    if (pickedTime == null) {
      return;
    }

    setState(() {
      if (isStartTime) {
        _startTime = pickedTime;
      } else {
        _endTime = pickedTime;
      }
    });
  }

  void _submit() {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    final int startMinutes = _startTime.hour * 60 + _startTime.minute;
    final int endMinutes = _endTime.hour * 60 + _endTime.minute;
    if (endMinutes <= startMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Jam selesai harus lebih besar dari jam mulai.'),
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      ScheduleDraft(
        title: _titleController.text,
        category: _selectedCategory,
        date: _selectedDate,
        startTime: _toApiTime(_startTime),
        endTime: _toApiTime(_endTime),
        location: _locationController.text,
        notes: _notesController.text,
      ),
    );
  }

  TimeOfDay _parseTime(String value) {
    final List<String> parts = normalizeTime(value).split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  String _toApiTime(TimeOfDay value) {
    final String hour = value.hour.toString().padLeft(2, '0');
    final String minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute:00';
  }

  String _formatTimeOfDay(TimeOfDay value) {
    final String hour = value.hour.toString().padLeft(2, '0');
    final String minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
        ),
        child: Text(value),
      ),
    );
  }
}

String formatDateLabel(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}
