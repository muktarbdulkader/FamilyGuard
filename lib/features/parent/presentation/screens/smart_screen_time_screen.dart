import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/rule_model.dart';
import '../../../../core/providers/rules_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../localization/smart_screen_time_l10n.dart';

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

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // ── Dynamic Theme & Accent Palette ───────────────────────────
  Color _tealAccent(AppColors c) =>
      c.isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0D9488);
  Color _indigoAccent(AppColors c) =>
      c.isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5);
  Color _roseAccent(AppColors c) =>
      c.isDark ? const Color(0xFFFB7185) : const Color(0xFFE11D48);
  Color _amberAccent(AppColors c) =>
      c.isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);

  // ── helpers ─────────────────────────────────────────────────
  String _fmtAmPm(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final p = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $p';
  }

  String _fmtMins(int mins, SmartScreenTimeL10n l10n) {
    if (mins < 60) {
      return l10n.languageCode == 'am'
          ? '$mins ደቂቃ'
          : l10n.languageCode == 'ar'
              ? '$mins د'
              : '${mins}m';
    }
    final h = mins ~/ 60;
    final m = mins % 60;
    if (m == 0) {
      return l10n.languageCode == 'am'
          ? '$h ሰዓት'
          : l10n.languageCode == 'ar'
              ? '$h س'
              : '${h}h';
    }
    return l10n.languageCode == 'am'
        ? '$h ሰ $m ደ'
        : l10n.languageCode == 'ar'
            ? '$h س $m د'
            : '${h}h ${m}m';
  }

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
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final colors = AppColors.of(ctx);
        final l10n = SmartScreenTimeL10n.of(ctx);
        final teal = _tealAccent(colors);
        final rose = _roseAccent(colors);

        return StatefulBuilder(
          builder: (ctx, setSheet) => Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: colors.border),
            ),
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
                      color: colors.textSecondary.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _sheetTitle(
                  Icons.timer_rounded,
                  teal,
                  l10n.dailyLimitTitle,
                  colors,
                ),
                const SizedBox(height: 20),

                // ── Hours slider ─────────────────────────────────
                Text(
                  '${l10n.dailyLimitHeader}: ${_fmtMins(minutes, l10n)}',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Slider(
                  value: minutes.toDouble(),
                  min: 15,
                  max: 480,
                  divisions: 31,
                  activeColor: teal,
                  inactiveColor: colors.border,
                  label: _fmtMins(minutes, l10n),
                  onChanged: (v) => setSheet(() {
                    minutes = v.round();
                    ctrl.text = v.round().toString();
                  }),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('15m',
                        style: TextStyle(
                            color: colors.textSecondary, fontSize: 11)),
                    Text('8h',
                        style: TextStyle(
                            color: colors.textSecondary, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Warning time ──────────────────────────────────
                Text(
                  l10n.warnBeforeLimit(warning),
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
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
                          color: sel ? teal : colors.surfaceHighlight,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: sel ? teal : colors.border,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          '${m}m',
                          style: TextStyle(
                            color: sel
                                ? (colors.isDark ? Colors.black : Colors.white)
                                : colors.textSecondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
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
                            _snack(l10n.dailyLimitRemovedSnack);
                          },
                          icon: Icon(Icons.delete_outline_rounded,
                              color: rose, size: 18),
                          label: Text(l10n.removeAction,
                              style: TextStyle(color: rose)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: rose),
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
                          final rule =
                              (existing ?? _blankRule(RuleType.screenTime))
                                  .copyWith(
                            ruleName: 'Daily Screen Time',
                            totalScreenTimeMinutes: minutes,
                            warningMinutes: warning,
                            description:
                                'Max ${_fmtMins(minutes, l10n)} screen time per day',
                            updatedAt: now,
                          );
                          await _saveRule(rule);
                          _snack(l10n.dailyLimitSavedSnack);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: teal,
                          foregroundColor:
                              colors.isDark ? Colors.black : Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(l10n.saveAction,
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showBedtimeDialog(RuleModel? existing) async {
    TimeOfDay start =
        existing?.bedtimeStart ?? const TimeOfDay(hour: 21, minute: 0);
    TimeOfDay end = existing?.bedtimeEnd ?? const TimeOfDay(hour: 7, minute: 0);
    List<int> days =
        List<int>.from(existing?.allowedDays ?? [1, 2, 3, 4, 5, 6, 7]);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final colors = AppColors.of(ctx);
        final l10n = SmartScreenTimeL10n.of(ctx);
        final indigo = _indigoAccent(colors);
        final amber = _amberAccent(colors);
        final rose = _roseAccent(colors);

        return StatefulBuilder(
          builder: (ctx, setSheet) => Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: colors.border),
            ),
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
                      color: colors.textSecondary.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _sheetTitle(
                  Icons.bedtime_rounded,
                  indigo,
                  l10n.bedtimeTitle,
                  colors,
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.deviceLockedOutsideHours,
                  style: TextStyle(color: colors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 24),

                // ── Time row ──────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _timePickerCard(
                        label: l10n.bedtimeLabel,
                        icon: Icons.nights_stay_rounded,
                        color: indigo,
                        time: start,
                        colors: colors,
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
                        label: l10n.wakeUpLabel,
                        icon: Icons.wb_sunny_rounded,
                        color: amber,
                        time: end,
                        colors: colors,
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
                Text(
                  l10n.applyOnDays,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 10),
                _daySelector(
                  selected: days,
                  colors: colors,
                  l10n: l10n,
                  onToggle: (d) => setSheet(() {
                    if (days.contains(d)) {
                      days.remove(d);
                    } else {
                      days.add(d);
                    }
                  }),
                ),
                const SizedBox(height: 28),

                Row(
                  children: [
                    if (existing != null && existing.id.isNotEmpty)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await _deleteRule(existing.id);
                            _snack(l10n.bedtimeRemovedSnack);
                          },
                          icon: Icon(Icons.delete_outline_rounded,
                              color: rose, size: 18),
                          label: Text(l10n.removeAction,
                              style: TextStyle(color: rose)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: rose),
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
                            _snack(l10n.selectAtLeastOneDaySnack);
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
                          _snack(l10n.bedtimeSavedSnack);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: indigo,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(l10n.saveAction,
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showFocusBlockDialog([RuleModel? existing]) async {
    final l10nInit = SmartScreenTimeL10n.of(context);
    TimeOfDay start =
        existing?.allowedStartTime ?? const TimeOfDay(hour: 15, minute: 0);
    TimeOfDay end =
        existing?.allowedEndTime ?? const TimeOfDay(hour: 17, minute: 0);
    List<int> days =
        List<int>.from(existing?.allowedDays ?? [1, 2, 3, 4, 5]);
    String label = existing?.ruleName ?? l10nInit.defaultFocusBlockName;
    final labelCtrl = TextEditingController(text: label);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final colors = AppColors.of(ctx);
        final l10n = SmartScreenTimeL10n.of(ctx);
        final amber = _amberAccent(colors);
        final rose = _roseAccent(colors);

        return StatefulBuilder(
          builder: (ctx, setSheet) => Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: colors.border),
            ),
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
                        color: colors.textSecondary.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _sheetTitle(
                    Icons.menu_book_rounded,
                    amber,
                    l10n.focusBlockSingular,
                    colors,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.blockDistractions,
                    style: TextStyle(color: colors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 20),

                  // Name field
                  TextField(
                    controller: labelCtrl,
                    style: TextStyle(color: colors.textPrimary),
                    decoration: InputDecoration(
                      labelText: l10n.blockNameLabel,
                      labelStyle: TextStyle(color: colors.textSecondary),
                      filled: true,
                      fillColor: colors.surfaceHighlight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: amber, width: 2),
                      ),
                    ),
                    onChanged: (v) => label = v,
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: _timePickerCard(
                          label: l10n.startLabel,
                          icon: Icons.play_circle_outline_rounded,
                          color: amber,
                          time: start,
                          colors: colors,
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
                          label: l10n.endLabel,
                          icon: Icons.stop_circle_outlined,
                          color: Colors.orange,
                          time: end,
                          colors: colors,
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

                  Text(
                    l10n.applyOnDays,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _daySelector(
                    selected: days,
                    colors: colors,
                    l10n: l10n,
                    onToggle: (d) => setSheet(() {
                      if (days.contains(d)) {
                        days.remove(d);
                      } else {
                        days.add(d);
                      }
                    }),
                  ),
                  const SizedBox(height: 28),

                  Row(
                    children: [
                      if (existing != null && existing.id.isNotEmpty)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              Navigator.pop(ctx);
                              await _deleteRule(existing.id);
                              _snack(l10n.focusRemovedSnack);
                            },
                            icon: Icon(Icons.delete_outline_rounded,
                                color: rose, size: 18),
                            label: Text(l10n.removeAction,
                                style: TextStyle(color: rose)),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: rose),
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
                              _snack(l10n.selectAtLeastOneDaySnack);
                              return;
                            }
                            final name = labelCtrl.text.trim();
                            if (name.isEmpty) {
                              _snack(l10n.enterBlockNameSnack);
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
                            _snack(l10n.focusSavedSnack);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: amber,
                            foregroundColor:
                                colors.isDark ? Colors.black : Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(l10n.saveAction,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── reusable sub-widgets ────────────────────────────────────
  Widget _sheetTitle(
    IconData icon,
    Color color,
    String text,
    AppColors colors,
  ) {
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
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _timePickerCard({
    required String label,
    required IconData icon,
    required Color color,
    required TimeOfDay time,
    required AppColors colors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: colors.surfaceHighlight,
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
                Text(
                  label,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _fmtAmPm(time),
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _daySelector({
    required List<int> selected,
    required AppColors colors,
    required SmartScreenTimeL10n l10n,
    required void Function(int) onToggle,
  }) {
    final labels = l10n.dayLabelsShort;
    final indigo = _indigoAccent(colors);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final day = i + 1;
        final isSel = selected.contains(day);
        return GestureDetector(
          onTap: () => onToggle(day),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSel ? indigo : colors.surfaceHighlight,
              border: Border.all(
                color: isSel ? indigo : colors.border,
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                labels[i],
                style: TextStyle(
                  color: isSel ? Colors.white : colors.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    final colors = AppColors.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: colors.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.border),
        ),
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
    final colors = AppColors.of(context);
    final l10n = SmartScreenTimeL10n.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: FadeTransition(
        opacity: _fadeIn,
        child: rulesAsync.when(
          loading: () => Center(
            child: CircularProgressIndicator(
              color: _tealAccent(colors),
              strokeWidth: 2.5,
            ),
          ),
          error: (e, _) => _buildError(e.toString(), colors, l10n),
          data: (rules) => _buildBody(rules, colors, l10n),
        ),
      ),
    );
  }

  Widget _buildError(String msg, AppColors colors, SmartScreenTimeL10n l10n) {
    final isIndexBuilding = msg.contains('failed-precondition') ||
        msg.contains('FAILED_PRECONDITION') ||
        msg.contains('index') ||
        msg.contains('Index');
    final teal = _tealAccent(colors);
    final rose = _roseAccent(colors);

    if (isIndexBuilding) {
      Future.delayed(const Duration(seconds: 8), () {
        if (mounted) {
          ref.invalidate(childRulesProvider(widget.childId));
        }
      });

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: teal.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    color: teal,
                    strokeWidth: 2.5,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.settingUpDatabaseTitle,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.firestoreBuildingSubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () =>
                    ref.refresh(childRulesProvider(widget.childId)),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(l10n.retryNowAction),
                style: ElevatedButton.styleFrom(
                  backgroundColor: teal,
                  foregroundColor: colors.isDark ? Colors.black : Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: rose, size: 48),
            const SizedBox(height: 12),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () =>
                  ref.refresh(childRulesProvider(widget.childId)),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(l10n.retryAction),
              style: ElevatedButton.styleFrom(
                backgroundColor: teal,
                foregroundColor: colors.isDark ? Colors.black : Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    List<RuleModel> rules,
    AppColors colors,
    SmartScreenTimeL10n l10n,
  ) {
    final screenTimeRule = _ruleOf(rules, RuleType.screenTime);
    final bedtimeRule = _ruleOf(rules, RuleType.bedtime);
    final focusRules = rules
        .where((r) => r.type == RuleType.appSchedule)
        .toList();
    final appLimitRules = rules
        .where((r) => r.type == RuleType.appLimit)
        .toList();

    final teal = _tealAccent(colors);
    final indigo = _indigoAccent(colors);
    final amber = _amberAccent(colors);
    final rose = _roseAccent(colors);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── App Bar ───────────────────────────────────────────
        SliverAppBar(
          backgroundColor: colors.background,
          expandedHeight: 130,
          floating: false,
          pinned: true,
          elevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: colors.textPrimary,
              size: 20,
            ),
          ),
          flexibleSpace: FlexibleSpaceBar(
            titlePadding:
                const EdgeInsets.only(left: 56, bottom: 16),
            title: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.screenTitle,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  widget.childName,
                  style: TextStyle(
                    color: teal,
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
                    teal.withOpacity(colors.isDark ? 0.12 : 0.08),
                    colors.background,
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
                  rules: rules,
                  screenTime: screenTimeRule,
                  bedtime: bedtimeRule,
                  focus: focusRules,
                  colors: colors,
                  l10n: l10n,
                ),
                const SizedBox(height: 20),

                // ── Section: Daily Limit ───────────────────────
                _sectionHeader(l10n.dailyLimitHeader, Icons.timer_rounded, teal),
                const SizedBox(height: 10),
                _buildDailyLimitCard(screenTimeRule, colors, l10n),
                const SizedBox(height: 20),

                // ── Section: Bedtime ───────────────────────────
                _sectionHeader(l10n.bedtimeTitle, Icons.bedtime_rounded, indigo),
                const SizedBox(height: 10),
                _buildBedtimeCard(bedtimeRule, colors, l10n),
                const SizedBox(height: 20),

                // ── Section: Focus Blocks ──────────────────────
                _sectionHeader(
                  l10n.focusBlocksTitle,
                  Icons.menu_book_rounded,
                  amber,
                  trailing: GestureDetector(
                    onTap: () => _showFocusBlockDialog(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: amber.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, color: amber, size: 14),
                          const SizedBox(width: 3),
                          Text(
                            l10n.addAction,
                            style: TextStyle(
                              color: amber,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (focusRules.isEmpty)
                  _buildEmptyCard(
                    icon: Icons.menu_book_outlined,
                    color: amber,
                    title: l10n.noFocusBlocksTitle,
                    subtitle: l10n.addStudyWindowSubtitle,
                    onAdd: () => _showFocusBlockDialog(),
                    addLabel: l10n.addFocusBlockAction,
                    colors: colors,
                  )
                else
                  ...focusRules.map(
                    (r) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildFocusRuleCard(r, colors, l10n),
                    ),
                  ),
                const SizedBox(height: 20),

                // ── Section: App Time Limits ───────────────────
                _sectionHeader(
                  l10n.appTimeLimitsTitle,
                  Icons.apps_rounded,
                  rose,
                ),
                const SizedBox(height: 10),
                if (appLimitRules.isEmpty)
                  _buildEmptyCard(
                    icon: Icons.hourglass_empty_rounded,
                    color: rose,
                    title: l10n.noAppLimitsTitle,
                    subtitle: l10n.setAppLimitsFromManagementSubtitle,
                    onAdd: null,
                    colors: colors,
                  )
                else
                  ...appLimitRules.map(
                    (r) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildAppLimitCard(r, colors, l10n),
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
  Widget _buildSummaryBanner({
    required List<RuleModel> rules,
    required RuleModel? screenTime,
    required RuleModel? bedtime,
    required List<RuleModel> focus,
    required AppColors colors,
    required SmartScreenTimeL10n l10n,
  }) {
    final activeCount = rules.where((r) => r.isActive).length;
    final dailyLimit = screenTime?.totalScreenTimeMinutes;
    final bedtimeActive =
        bedtime != null && bedtime.status == RuleStatus.active;
    final teal = _tealAccent(colors);
    final indigo = _indigoAccent(colors);
    final amber = _amberAccent(colors);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: teal.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: colors.isDark
                ? teal.withOpacity(0.04)
                : Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _statCell(
              value: activeCount.toString(),
              label: l10n.activeRulesStat,
              color: teal,
              colors: colors,
            ),
          ),
          _divider(colors),
          Expanded(
            child: _statCell(
              value: dailyLimit != null ? _fmtMins(dailyLimit, l10n) : '—',
              label: l10n.dailyLimitStat,
              color: teal,
              colors: colors,
            ),
          ),
          _divider(colors),
          Expanded(
            child: _statCell(
              value: bedtimeActive ? l10n.onStatus : l10n.offStatus,
              label: l10n.bedtimeStat,
              color: bedtimeActive ? indigo : colors.textSecondary,
              colors: colors,
            ),
          ),
          _divider(colors),
          Expanded(
            child: _statCell(
              value: focus.length.toString(),
              label: l10n.focusBlocksStat,
              color: amber,
              colors: colors,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCell({
    required String value,
    required String label,
    required Color color,
    required AppColors colors,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.textSecondary, fontSize: 10),
        ),
      ],
    );
  }

  Widget _divider(AppColors colors) => Container(
        width: 1,
        height: 36,
        color: colors.border,
        margin: const EdgeInsets.symmetric(horizontal: 2),
      );

  // ── Section header ──────────────────────────────────────────
  Widget _sectionHeader(
    String title,
    IconData icon,
    Color color, {
    Widget? trailing,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 7),
        Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        const Spacer(),
        ?trailing,
      ],
    );
  }

  // ── Daily limit card ─────────────────────────────────────────
  Widget _buildDailyLimitCard(
    RuleModel? rule,
    AppColors colors,
    SmartScreenTimeL10n l10n,
  ) {
    final hasRule = rule != null;
    final isActive = hasRule && rule.status == RuleStatus.active;
    final limit = rule?.totalScreenTimeMinutes;
    final teal = _tealAccent(colors);
    final amber = _amberAccent(colors);

    return _ruleCard(
      color: teal,
      icon: Icons.timer_rounded,
      title: hasRule
          ? l10n.maxPerDay(_fmtMins(limit ?? 0, l10n))
          : l10n.notSetTapToConfigure,
      subtitle: hasRule
          ? '${l10n.warnBeforeLimit(rule.warningMinutes ?? 15)} · ${isActive ? l10n.activeStatus : l10n.pausedStatus}'
          : l10n.totalScreenTimeFor(widget.childName),
      statusColor: hasRule ? (isActive ? teal : amber) : colors.textSecondary,
      statusLabel: hasRule
          ? (isActive ? l10n.activeStatus : l10n.pausedStatus)
          : l10n.notSetStatus,
      colors: colors,
      trailing: hasRule
          ? Switch(
              value: isActive,
              activeColor: teal,
              onChanged: (v) => _toggleRule(rule, v),
            )
          : null,
      onTap: () => _showDailyLimitDialog(rule),
    );
  }

  // ── Bedtime card ─────────────────────────────────────────────
  Widget _buildBedtimeCard(
    RuleModel? rule,
    AppColors colors,
    SmartScreenTimeL10n l10n,
  ) {
    final hasRule = rule != null;
    final isActive = hasRule && rule.status == RuleStatus.active;
    final indigo = _indigoAccent(colors);
    final amber = _amberAccent(colors);

    String timeRange = l10n.notSetStatus;
    if (hasRule && rule.bedtimeStart != null && rule.bedtimeEnd != null) {
      timeRange =
          '${_fmtAmPm(rule.bedtimeStart!)} – ${_fmtAmPm(rule.bedtimeEnd!)}';
    }

    String daysLabel = '';
    if (hasRule && rule.allowedDays != null) {
      if (rule.allowedDays!.length == 7) {
        daysLabel = l10n.everyDay;
      } else {
        final labels = l10n.dayNamesMedium;
        final sorted = List<int>.from(rule.allowedDays!)..sort();
        daysLabel = sorted
            .map((d) => d < labels.length ? labels[d] : '')
            .where((s) => s.isNotEmpty)
            .join(', ');
      }
    }

    return _ruleCard(
      color: indigo,
      icon: Icons.bedtime_rounded,
      title: hasRule ? timeRange : l10n.notSetTapToConfigure,
      subtitle: hasRule
          ? '${isActive ? l10n.activeStatus : l10n.pausedStatus} · $daysLabel'
          : l10n.bedtimeFor(widget.childName),
      statusColor: hasRule ? (isActive ? indigo : amber) : colors.textSecondary,
      statusLabel: hasRule
          ? (isActive ? l10n.activeStatus : l10n.pausedStatus)
          : l10n.notSetStatus,
      colors: colors,
      trailing: hasRule
          ? Switch(
              value: isActive,
              activeColor: indigo,
              onChanged: (v) => _toggleRule(rule, v),
            )
          : null,
      onTap: () => _showBedtimeDialog(rule),
    );
  }

  // ── Focus block card ──────────────────────────────────────────
  Widget _buildFocusRuleCard(
    RuleModel rule,
    AppColors colors,
    SmartScreenTimeL10n l10n,
  ) {
    final isActive = rule.status == RuleStatus.active;
    final amber = _amberAccent(colors);

    String timeRange = '';
    if (rule.allowedStartTime != null && rule.allowedEndTime != null) {
      timeRange =
          '${_fmtAmPm(rule.allowedStartTime!)} – ${_fmtAmPm(rule.allowedEndTime!)}';
    }

    String daysLabel = l10n.everyDay;
    if (rule.allowedDays != null && rule.allowedDays!.length < 7) {
      final labels = l10n.dayLabelsShort;
      daysLabel = (List<int>.from(rule.allowedDays!)..sort())
          .map((d) => (d - 1 >= 0 && d - 1 < labels.length) ? labels[d - 1] : '')
          .join(' ');
    }

    return _ruleCard(
      color: amber,
      icon: Icons.menu_book_rounded,
      title: rule.ruleName,
      subtitle: '$timeRange · $daysLabel',
      statusColor: isActive ? amber : colors.textSecondary,
      statusLabel: isActive ? l10n.activeStatus : l10n.pausedStatus,
      colors: colors,
      trailing: Switch(
        value: isActive,
        activeColor: amber,
        onChanged: (v) => _toggleRule(rule, v),
      ),
      onTap: () => _showFocusBlockDialog(rule),
    );
  }

  // ── App limit card (read-only here) ──────────────────────────
  Widget _buildAppLimitCard(
    RuleModel rule,
    AppColors colors,
    SmartScreenTimeL10n l10n,
  ) {
    final isActive = rule.status == RuleStatus.active;
    final limit = rule.dailyLimitMinutes;
    final rose = _roseAccent(colors);

    return _ruleCard(
      color: rose,
      icon: Icons.hourglass_bottom_rounded,
      title: rule.appName ?? rule.appPackageName ?? 'Unknown App',
      subtitle: limit != null
          ? '${_fmtMins(limit, l10n)} / ${l10n.dailyLimitStat} · ${isActive ? l10n.activeStatus : l10n.pausedStatus}'
          : '${l10n.activeRulesStat} · ${isActive ? l10n.activeStatus : l10n.pausedStatus}',
      statusColor: isActive ? rose : colors.textSecondary,
      statusLabel: isActive ? l10n.activeStatus : l10n.pausedStatus,
      colors: colors,
      trailing: Switch(
        value: isActive,
        activeColor: rose,
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
    required AppColors colors,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colors.isDark
                ? color.withOpacity(0.2)
                : colors.border,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.isDark
                  ? color.withOpacity(0.04)
                  : Colors.black.withOpacity(0.03),
              blurRadius: 10,
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
                  Text(
                    title,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing,
            ] else if (onTap != null) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: colors.textSecondary.withOpacity(0.5),
                size: 20,
              ),
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
    required AppColors colors,
    String addLabel = 'Configure',
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: color.withOpacity(0.4), size: 36),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textSecondary, fontSize: 12),
          ),
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
                child: Text(
                  addLabel,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
