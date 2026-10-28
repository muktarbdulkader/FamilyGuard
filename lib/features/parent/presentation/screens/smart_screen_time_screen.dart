import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/rule_model.dart';
import '../../../../core/providers/rules_provider.dart';

// ─────────────────────────────────────────────────────────────
// Screen entry point — receives child info from caller
// ─────────────────────────────────────────────────────────────

class SmartScreenTimeScreen extends ConsumerStatefulWidget {
  final String familyId;
  final String childId;
  final String childName;

  const SmartScreenTimeScreen({
    super.key,
    required this.familyId,
    required this.childId,
    required this.childName,
  });

  @override
  ConsumerState<SmartScreenTimeScreen> createState() =>
      _SmartScreenTimeScreenState();
}

class _SmartScreenTimeScreenState
    extends ConsumerState<SmartScreenTimeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeIn;

  // ── colour palette ──────────────────────────────────────────
  static const _bg = Color(0xFF0B0F19);
  static const _surface = Color(0xFF111827);
  static const _card = Color(0xFF1A2235);
  static const _border = Color(0xFF1E293B);
  static const _teal = Color(0xFF14B8A6);
  static const _indigo = Color(0xFF4F46E5);
  static const _rose = Color(0xFFE11D48);
  static const _amber = Color(0xFFF59E0B);
  static const _textPrimary = Colors.white;
  static const _textSec = Color(0xFF94A3B8);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // ── helpers ─────────────────────────────────────────────────
  String _fmtAmPm(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final p = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $p';
  }

  String _fmtMins(int mins) {
    if (mins < 60) return '${mins}m';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  // find first rule of a given type (or null)
  RuleModel? _ruleOf(List<RuleModel> rules, RuleType t) =>
      rules.where((r) => r.type == t).firstOrNull;

  // ── SAVE helpers ────────────────────────────────────────────

  Future<void> _saveRule(RuleModel rule) async {
    final svc = ref.read(rulesServiceProvider);
    if (rule.id.isEmpty) {
      await svc.createRule(rule);
    } else {
      await svc.updateRule(rule.id, rule);
    }
  }

  Future<void> _toggleRule(RuleModel rule, bool enable) async {
    final svc = ref.read(rulesServiceProvider);
    await svc.toggleRuleStatus(
      rule.id,
      enable ? RuleStatus.active : RuleStatus.paused,
    );
  }

  Future<void> _deleteRule(String id) async {
    final svc = ref.read(rulesServiceProvider);
    await svc.deleteRule(id);
  }

  RuleModel _blankRule(RuleType type) => RuleModel(
        id: '',
        familyId: widget.familyId,
        childId: widget.childId,
        ruleName: '',
        type: type,
        status: RuleStatus.active,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        sendNotifications: true,
      );

  // ── DIALOGS ─────────────────────────────────────────────────

  Future<void> _showDailyLimitDialog(RuleModel? existing) async {
    int minutes = existing?.totalScreenTimeMinutes ?? 120;
    final ctrl = TextEditingController(text: minutes.toString());
    int warning = existing?.warningMinutes ?? 15;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _textSec.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _sheetTitle(Icons.timer_rounded, _teal, 'Daily Screen Time Limit'),
              const SizedBox(height: 20),

              // ── Hours slider ─────────────────────────────────
              Text('Daily limit: ${_fmtMins(minutes)}',
                  style: const TextStyle(
                      color: _textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Slider(
                value: minutes.toDouble(),
                min: 15,
                max: 480,
                divisions: 31,
                activeColor: _teal,
                inactiveColor: _border,
                label: _fmtMins(minutes),
                onChanged: (v) => setSheet(() {
                  minutes = v.round();
                  ctrl.text = v.round().toString();
                }),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('15m', style: TextStyle(color: _textSec, fontSize: 11)),
                  Text('8h', style: TextStyle(color: _textSec, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 20),

              // ── Warning time ──────────────────────────────────
              Text('Warn before limit:',
                  style: const TextStyle(
                      color: _textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [5, 10, 15, 30].map((m) {
                  final sel = warning == m;
                  return GestureDetector(
                    onTap: () => setSheet(() => warning = m),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? _teal : _surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: sel ? _teal : _border, width: 1.5),
                      ),
                      child: Text('${m}m',
                          style: TextStyle(
                              color: sel ? Colors.black : _textSec,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 28),

              // ── Buttons ───────────────────────────────────────
              Row(
                children: [
                  if (existing != null && existing.id.isNotEmpty)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _deleteRule(existing.id);
                          _snack('Daily limit removed');
                        },
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: _rose, size: 18),
                        label: const Text('Remove',
                            style: TextStyle(color: _rose)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: _rose),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  if (existing != null && existing.id.isNotEmpty)
                    const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final now = DateTime.now();
                        final rule = (existing ?? _blankRule(RuleType.screenTime))
                            .copyWith(
                          ruleName: 'Daily Screen Time',
                          totalScreenTimeMinutes: minutes,
                          warningMinutes: warning,
                          description:
                              'Max ${_fmtMins(minutes)} screen time per day',
                          updatedAt: now,
                        );
                        await _saveRule(rule);
                        _snack('Daily limit saved ✓');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _teal,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Save',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showBedtimeDialog(RuleModel? existing) async {
    TimeOfDay start = existing?.bedtimeStart ?? const TimeOfDay(hour: 21, minute: 0);
    TimeOfDay end = existing?.bedtimeEnd ?? const TimeOfDay(hour: 7, minute: 0);
    List<int> days = List<int>.from(
        existing?.allowedDays ?? [1, 2, 3, 4, 5, 6, 7]);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _textSec.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _sheetTitle(Icons.bedtime_rounded, _indigo, 'Bedtime Schedule'),
              const SizedBox(height: 6),
              Text(
                'Device will be locked outside allowed hours.',
                style: TextStyle(color: _textSec, fontSize: 13),
              ),
              const SizedBox(height: 24),

              // ── Time row ──────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _timePickerCard(
                      label: 'Bedtime',
                      icon: Icons.nights_stay_rounded,
                      color: _indigo,
                      time: start,
                      onTap: () async {
                        final t = await showTimePicker(
                            context: ctx, initialTime: start);
                        if (t != null) setSheet(() => start = t);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _timePickerCard(
                      label: 'Wake up',
                      icon: Icons.wb_sunny_rounded,
                      color: _amber,
                      time: end,
                      onTap: () async {
                        final t = await showTimePicker(
                            context: ctx, initialTime: end);
                        if (t != null) setSheet(() => end = t);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Days ─────────────────────────────────────────
              Text('Apply on:',
                  style: const TextStyle(
                      color: _textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
              const SizedBox(height: 10),
              _daySelector(days, (d) => setSheet(() {
                    if (days.contains(d)) {
                      days.remove(d);
                    } else {
                      days.add(d);
                    }
                  })),
              const SizedBox(height: 28),

              Row(
                children: [
                  if (existing != null && existing.id.isNotEmpty)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _deleteRule(existing.id);
                          _snack('Bedtime rule removed');
                        },
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: _rose, size: 18),
                        label:
                            const Text('Remove', style: TextStyle(color: _rose)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: _rose),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  if (existing != null && existing.id.isNotEmpty)
                    const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (days.isEmpty) {
                          _snack('Select at least one day');
                          return;
                        }
                        Navigator.pop(ctx);
                        final now = DateTime.now();
                        final rule =
                            (existing ?? _blankRule(RuleType.bedtime)).copyWith(
                          ruleName: 'Bedtime',
                          bedtimeStart: start,
                          bedtimeEnd: end,
                          bedtimeEnabled: true,
                          allowedDays: List<int>.from(days),
                          description:
                              'No screen from ${_fmtAmPm(start)} to ${_fmtAmPm(end)}',
                          updatedAt: now,
                        );
                        await _saveRule(rule);
                        _snack('Bedtime schedule saved ✓');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _indigo,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Save',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showFocusBlockDialog([RuleModel? existing]) async {
    TimeOfDay start =
        existing?.allowedStartTime ?? const TimeOfDay(hour: 15, minute: 0);
    TimeOfDay end =
        existing?.allowedEndTime ?? const TimeOfDay(hour: 17, minute: 0);
    List<int> days =
        List<int>.from(existing?.allowedDays ?? [1, 2, 3, 4, 5]);
    String label = existing?.ruleName ?? 'Study Focus';
    final labelCtrl = TextEditingController(text: label);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 28),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _textSec.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _sheetTitle(Icons.menu_book_rounded, _amber, 'Focus Block'),
                const SizedBox(height: 6),
                Text(
                  'Block distracting apps during this window.',
                  style: TextStyle(color: _textSec, fontSize: 13),
                ),
                const SizedBox(height: 20),

                // Name field
                TextField(
                  controller: labelCtrl,
                  style: const TextStyle(color: _textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Block name',
                    labelStyle: TextStyle(color: _textSec),
                    filled: true,
                    fillColor: _surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _amber),
                    ),
                  ),
                  onChanged: (v) => label = v,
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: _timePickerCard(
                        label: 'Start',
                        icon: Icons.play_circle_outline_rounded,
                        color: _amber,
                        time: start,
                        onTap: () async {
                          final t = await showTimePicker(
                              context: ctx, initialTime: start);
                          if (t != null) setSheet(() => start = t);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _timePickerCard(
                        label: 'End',
                        icon: Icons.stop_circle_outlined,
                        color: Colors.orange,
                        time: end,
                        onTap: () async {
                          final t = await showTimePicker(
                              context: ctx, initialTime: end);
                          if (t != null) setSheet(() => end = t);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                Text('Apply on:',
                    style: const TextStyle(
                        color: _textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                const SizedBox(height: 10),
                _daySelector(days, (d) => setSheet(() {
                      if (days.contains(d)) {
                        days.remove(d);
                      } else {
                        days.add(d);
                      }
                    })),
                const SizedBox(height: 28),

                Row(
                  children: [
                    if (existing != null && existing.id.isNotEmpty)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await _deleteRule(existing.id);
                            _snack('Focus block removed');
                          },
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: _rose, size: 18),
                          label: const Text('Remove',
                              style: TextStyle(color: _rose)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: _rose),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    if (existing != null && existing.id.isNotEmpty)
                      const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (days.isEmpty) {
                            _snack('Select at least one day');
                            return;
                          }
                          final name = labelCtrl.text.trim();
                          if (name.isEmpty) {
                            _snack('Enter a block name');
                            return;
                          }
                          Navigator.pop(ctx);
                          final now = DateTime.now();
                          final rule =
                              (existing ?? _blankRule(RuleType.appSchedule))
                                  .copyWith(
                            ruleName: name,
                            allowedStartTime: start,
                            allowedEndTime: end,
                            allowedDays: List<int>.from(days),
                            description:
                                'Focus block ${_fmtAmPm(start)} – ${_fmtAmPm(end)}',
                            updatedAt: now,
                          );
                          await _saveRule(rule);
                          _snack('Focus block saved ✓');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _amber,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Save',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── reusable sub-widgets ────────────────────────────────────

  Widget _sheetTitle(IconData icon, Color color, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Text(text,
            style: const TextStyle(
                color: _textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _timePickerCard({
    required String label,
    required IconData icon,
    required Color color,
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.4), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 14),
                const SizedBox(width: 4),
                Text(label,
                    style: TextStyle(
                        color: _textSec,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 6),
            Text(_fmtAmPm(time),
                style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }

  Widget _daySelector(List<int> selected, void Function(int) onToggle) {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final day = i + 1;
        final isSel = selected.contains(day);
        return GestureDetector(
          onTap: () => onToggle(day),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSel ? _indigo : _surface,
              border: Border.all(
                  color: isSel ? _indigo : _border, width: 1.5),
            ),
            child: Center(
              child: Text(labels[i],
                  style: TextStyle(
                      color: isSel ? Colors.white : _textSec,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
            ),
          ),
        );
      }),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final rulesAsync = ref.watch(childRulesProvider(widget.childId));

    return Scaffold(
      backgroundColor: _bg,
      body: FadeTransition(
        opacity: _fadeIn,
        child: rulesAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: _teal, strokeWidth: 2.5),
          ),
          error: (e, _) => _buildError(e.toString()),
          data: (rules) => _buildBody(rules),
        ),
      ),
    );
  }

  Widget _buildError(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: _rose, size: 48),
            const SizedBox(height: 12),
            Text(msg,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _textSec)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () =>
                  ref.refresh(childRulesProvider(widget.childId)),
              style: ElevatedButton.styleFrom(backgroundColor: _teal),
              child: const Text('Retry',
                  style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(List<RuleModel> rules) {
    final screenTimeRule = _ruleOf(rules, RuleType.screenTime);
    final bedtimeRule = _ruleOf(rules, RuleType.bedtime);
    final focusRules = rules
        .where((r) => r.type == RuleType.appSchedule)
        .toList();
    final appLimitRules = rules
        .where((r) => r.type == RuleType.appLimit)
        .toList();

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── App Bar ───────────────────────────────────────────
        SliverAppBar(
          backgroundColor: _bg,
          expandedHeight: 130,
          floating: false,
          pinned: true,
          elevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: _textPrimary, size: 20),
          ),
          flexibleSpace: FlexibleSpaceBar(
            titlePadding:
                const EdgeInsets.only(left: 56, bottom: 16),
            title: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Smart Screen Time',
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  widget.childName,
                  style: const TextStyle(
                    color: _teal,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _teal.withOpacity(0.12),
                    _bg,
                  ],
                ),
              ),
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Summary banner ─────────────────────────────
                _buildSummaryBanner(
                    rules, screenTimeRule, bedtimeRule, focusRules),
                const SizedBox(height: 20),

                // ── Section: Daily Limit ───────────────────────
                _sectionHeader('Daily Limit', Icons.timer_rounded, _teal),
                const SizedBox(height: 10),
                _buildDailyLimitCard(screenTimeRule),
                const SizedBox(height: 20),

                // ── Section: Bedtime ───────────────────────────
                _sectionHeader('Bedtime Schedule', Icons.bedtime_rounded, _indigo),
                const SizedBox(height: 10),
                _buildBedtimeCard(bedtimeRule),
                const SizedBox(height: 20),

                // ── Section: Focus Blocks ──────────────────────
                _sectionHeader('Focus Blocks', Icons.menu_book_rounded, _amber,
                    trailing: GestureDetector(
                      onTap: () => _showFocusBlockDialog(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _amber.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.add, color: _amber, size: 14),
                            SizedBox(width: 3),
                            Text('Add',
                                style: TextStyle(
                                    color: _amber,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    )),
                const SizedBox(height: 10),
                if (focusRules.isEmpty)
                  _buildEmptyCard(
                    icon: Icons.menu_book_outlined,
                    color: _amber,
                    title: 'No focus blocks yet',
                    subtitle: 'Add a study window to block distractions',
                    onAdd: () => _showFocusBlockDialog(),
                    addLabel: 'Add Focus Block',
                  )
                else
                  ...focusRules.map(
                    (r) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildFocusRuleCard(r),
                    ),
                  ),
                const SizedBox(height: 20),

                // ── Section: App Time Limits ───────────────────
                _sectionHeader(
                    'App Time Limits', Icons.apps_rounded, _rose),
                const SizedBox(height: 10),
                if (appLimitRules.isEmpty)
                  _buildEmptyCard(
                    icon: Icons.hourglass_empty_rounded,
                    color: _rose,
                    title: 'No per-app limits',
                    subtitle:
                        'Set per-app limits from the App Management screen',
                    onAdd: null,
                  )
                else
                  ...appLimitRules.map(
                    (r) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildAppLimitCard(r),
                    ),
                  ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Summary banner ──────────────────────────────────────────
  Widget _buildSummaryBanner(
    List<RuleModel> rules,
    RuleModel? screenTime,
    RuleModel? bedtime,
    List<RuleModel> focus,
  ) {
    final activeCount = rules.where((r) => r.isActive).length;
    final dailyLimit = screenTime?.totalScreenTimeMinutes;
    final bedtimeActive =
        bedtime != null && bedtime.status == RuleStatus.active;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_teal.withOpacity(0.12), _indigo.withOpacity(0.08)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _teal.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _statCell(
              value: activeCount.toString(),
              label: 'Active rules',
              color: _teal,
            ),
          ),
          _divider(),
          Expanded(
            child: _statCell(
              value: dailyLimit != null ? _fmtMins(dailyLimit) : '—',
              label: 'Daily limit',
              color: _teal,
            ),
          ),
          _divider(),
          Expanded(
            child: _statCell(
              value: bedtimeActive ? 'On' : 'Off',
              label: 'Bedtime',
              color: bedtimeActive ? _indigo : _textSec,
            ),
          ),
          _divider(),
          Expanded(
            child: _statCell(
              value: focus.length.toString(),
              label: 'Focus blocks',
              color: _amber,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCell(
      {required String value, required String label, required Color color}) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _textSec, fontSize: 10)),
      ],
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 36,
        color: _border,
        margin: const EdgeInsets.symmetric(horizontal: 2),
      );

  // ── Section header ──────────────────────────────────────────
  Widget _sectionHeader(String title, IconData icon, Color color,
      {Widget? trailing}) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 7),
        Text(title,
            style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3)),
        const Spacer(),
        ?trailing,
      ],
    );
  }

  // ── Daily limit card ─────────────────────────────────────────
  Widget _buildDailyLimitCard(RuleModel? rule) {
    final hasRule = rule != null;
    final isActive = hasRule && rule.status == RuleStatus.active;
    final limit = rule?.totalScreenTimeMinutes;

    return _ruleCard(
      color: _teal,
      icon: Icons.timer_rounded,
      title: hasRule
          ? 'Max ${_fmtMins(limit ?? 0)} per day'
          : 'Not set — tap to configure',
      subtitle: hasRule
          ? 'Warn ${rule.warningMinutes ?? 15}m before limit · ${isActive ? "Active" : "Paused"}'
          : 'Total device screen time for ${widget.childName}',
      statusColor: hasRule ? (isActive ? _teal : _amber) : _textSec,
      statusLabel: hasRule ? (isActive ? 'Active' : 'Paused') : 'Not set',
      trailing: hasRule
          ? Switch(
              value: isActive,
              activeColor: _teal,
              onChanged: (v) => _toggleRule(rule, v),
            )
          : null,
      onTap: () => _showDailyLimitDialog(rule),
    );
  }

  // ── Bedtime card ─────────────────────────────────────────────
  Widget _buildBedtimeCard(RuleModel? rule) {
    final hasRule = rule != null;
    final isActive = hasRule && rule.status == RuleStatus.active;

    String timeRange = 'Not set';
    if (hasRule && rule.bedtimeStart != null && rule.bedtimeEnd != null) {
      timeRange =
          '${_fmtAmPm(rule.bedtimeStart!)} – ${_fmtAmPm(rule.bedtimeEnd!)}';
    }

    String daysLabel = '';
    if (hasRule && rule.allowedDays != null) {
      const labels = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final sorted = List<int>.from(rule.allowedDays!)..sort();
      daysLabel = sorted.map((d) => labels[d]).join(', ');
    }

    return _ruleCard(
      color: _indigo,
      icon: Icons.bedtime_rounded,
      title: hasRule ? timeRange : 'Not set — tap to configure',
      subtitle: hasRule
          ? '${isActive ? "Active" : "Paused"} · $daysLabel'
          : 'Set quiet hours for ${widget.childName}',
      statusColor: hasRule ? (isActive ? _indigo : _amber) : _textSec,
      statusLabel: hasRule ? (isActive ? 'Active' : 'Paused') : 'Not set',
      trailing: hasRule
          ? Switch(
              value: isActive,
              activeColor: _indigo,
              onChanged: (v) => _toggleRule(rule, v),
            )
          : null,
      onTap: () => _showBedtimeDialog(rule),
    );
  }

  // ── Focus block card ──────────────────────────────────────────
  Widget _buildFocusRuleCard(RuleModel rule) {
    final isActive = rule.status == RuleStatus.active;
    String timeRange = '';
    if (rule.allowedStartTime != null && rule.allowedEndTime != null) {
      timeRange =
          '${_fmtAmPm(rule.allowedStartTime!)} – ${_fmtAmPm(rule.allowedEndTime!)}';
    }
    const labels = ['', 'M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final daysLabel = rule.allowedDays != null
        ? (List<int>.from(rule.allowedDays!)..sort())
            .map((d) => labels[d])
            .join(' ')
        : 'Every day';

    return _ruleCard(
      color: _amber,
      icon: Icons.menu_book_rounded,
      title: rule.ruleName,
      subtitle: '$timeRange · $daysLabel',
      statusColor: isActive ? _amber : _textSec,
      statusLabel: isActive ? 'Active' : 'Paused',
      trailing: Switch(
        value: isActive,
        activeColor: _amber,
        onChanged: (v) => _toggleRule(rule, v),
      ),
      onTap: () => _showFocusBlockDialog(rule),
    );
  }

  // ── App limit card (read-only here) ──────────────────────────
  Widget _buildAppLimitCard(RuleModel rule) {
    final isActive = rule.status == RuleStatus.active;
    final limit = rule.dailyLimitMinutes;

    return _ruleCard(
      color: _rose,
      icon: Icons.hourglass_bottom_rounded,
      title: rule.appName ?? rule.appPackageName ?? 'Unknown App',
      subtitle: limit != null
          ? '${_fmtMins(limit)} per day · ${isActive ? "Active" : "Paused"}'
          : 'Limit set · ${isActive ? "Active" : "Paused"}',
      statusColor: isActive ? _rose : _textSec,
      statusLabel: isActive ? 'Active' : 'Paused',
      trailing: Switch(
        value: isActive,
        activeColor: _rose,
        onChanged: (v) => _toggleRule(rule, v),
      ),
      onTap: null,
    );
  }

  // ── Generic rule card ─────────────────────────────────────────
  Widget _ruleCard({
    required Color color,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color statusColor,
    required String statusLabel,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.18), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: _textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: const TextStyle(
                          color: _textSec, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(statusLabel,
                        style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing,
            ] else if (onTap != null) ...[
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded,
                  color: _textSec.withOpacity(0.5), size: 20),
            ],
          ],
        ),
      ),
    );
  }

  // ── Empty state card ──────────────────────────────────────────
  Widget _buildEmptyCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback? onAdd,
    String addLabel = 'Configure',
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Icon(icon, color: color.withOpacity(0.35), size: 36),
          const SizedBox(height: 10),
          Text(title,
              style: const TextStyle(
                  color: _textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14)),
          const SizedBox(height: 4),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _textSec, fontSize: 12)),
          if (onAdd != null) ...[
            const SizedBox(height: 14),
            GestureDetector(
              onTap: onAdd,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 9),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Text(addLabel,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

