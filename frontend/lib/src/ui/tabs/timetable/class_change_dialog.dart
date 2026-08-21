import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/nest_models.dart';
import '../../../state/nest_controller.dart';
import '../../nest_theme.dart';
import '../../widgets/search_select_field.dart';

/// 수업 변경(class_session_changes) 등록·수정·발송 UI.
///
/// 시간표는 주간 반복 템플릿이라 세션 자체에는 날짜가 없다. 그래서 "이번 주만"
/// 같은 1회성 변경은 [ClassSessionChange.effectiveFrom] == [effectiveTo] 인
/// 하루짜리 행으로, "학기 남은 기간"은 종료일 없는 행으로 표현한다.
///
/// 발송은 절대 자동으로 하지 않는다. 저장 후 반드시 확인 다이얼로그를 거친다
/// (실제 문자 요금이 나가고 되돌릴 수 없다).

/// 변경 유형 선택지. 값은 DB check 제약(change_type)과 1:1로 맞춘다.
class _ChangeTypeOption {
  const _ChangeTypeOption({
    required this.value,
    required this.label,
    required this.description,
    required this.icon,
  });

  final String value;
  final String label;
  final String description;
  final IconData icon;
}

const List<_ChangeTypeOption> _changeTypeOptions = <_ChangeTypeOption>[
  _ChangeTypeOption(
    value: 'CANCELED',
    label: '휴강',
    description: '해당 회차 수업을 하지 않습니다.',
    icon: Icons.event_busy_outlined,
  ),
  _ChangeTypeOption(
    value: 'TIME_MOVED',
    label: '시간 변경',
    description: '다른 교시로 옮겨서 진행합니다.',
    icon: Icons.schedule_outlined,
  ),
  _ChangeTypeOption(
    value: 'ROOM_MOVED',
    label: '장소 변경',
    description: '다른 교실/장소에서 진행합니다.',
    icon: Icons.meeting_room_outlined,
  ),
  _ChangeTypeOption(
    value: 'TEACHER_SUBSTITUTE',
    label: '보강 교사',
    description: '다른 선생님이 대신 들어갑니다.',
    icon: Icons.person_pin_outlined,
  ),
  _ChangeTypeOption(
    value: 'NOTE',
    label: '안내',
    description: '준비물 등 전달 사항만 알립니다.',
    icon: Icons.campaign_outlined,
  ),
];

_ChangeTypeOption _changeTypeOptionOf(String value) {
  return _changeTypeOptions.firstWhere(
    (option) => option.value == value,
    orElse: () => _changeTypeOptions.last,
  );
}

/// 적용 범위. 사용자가 날짜 계산을 직접 하지 않아도 되게 3가지로 묶는다.
enum _ChangeScope {
  /// 그 주 해당 요일 하루만 (effectiveFrom == effectiveTo).
  singleDay,

  /// 시작일부터 학기 끝까지 (effectiveTo == null).
  restOfTerm,

  /// 시작일 ~ 종료일 직접 지정.
  custom,
}

// ---------------------------------------------------------------------------
// 공개 API
// ---------------------------------------------------------------------------

/// 한 수업의 변경 내역 시트. 등록/수정/삭제/발송을 모두 여기서 처리한다.
Future<void> showClassSessionChangeSheet({
  required BuildContext context,
  required NestController controller,
  required String classSessionId,
}) async {
  if (!controller.canManageClassSessionChanges) {
    _showMessage(context, '수업 변경은 담당 교사 또는 관리자/스태프만 등록할 수 있습니다.');
    return;
  }
  final session = findClassSessionById(controller, classSessionId);
  if (session == null) {
    _showMessage(context, '수업 정보를 찾을 수 없습니다.');
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) {
      return AnimatedBuilder(
        animation: controller,
        builder: (innerContext, _) {
          final changes = controller.changesForSession(classSessionId);
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.published_with_changes, color: NestColors.clay),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '수업 변경 공지',
                        style: Theme.of(innerContext).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  classSessionHeadline(controller, session),
                  style: Theme.of(innerContext).textTheme.bodyMedium?.copyWith(
                    color: NestColors.deepWood.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: controller.isBusy
                        ? null
                        : () => showClassSessionChangeEditor(
                            context: innerContext,
                            controller: controller,
                            classSessionId: classSessionId,
                          ),
                    icon: const Icon(Icons.add),
                    label: const Text('변경 등록'),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '등록된 변경',
                  style: Theme.of(innerContext).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (changes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      '등록된 수업 변경이 없습니다.',
                      style: Theme.of(innerContext).textTheme.bodySmall,
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight:
                          MediaQuery.of(innerContext).size.height * 0.42,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        children: changes
                            .map(
                              (change) => ClassSessionChangeTile(
                                controller: controller,
                                change: change,
                                showSessionName: false,
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      );
    },
  );
}

/// 등록/수정 다이얼로그. 저장에 성공하면 곧바로 발송 확인 단계로 넘어간다.
/// 저장했으면 true.
Future<bool> showClassSessionChangeEditor({
  required BuildContext context,
  required NestController controller,
  required String classSessionId,
  ClassSessionChange? existing,
}) async {
  if (!controller.canManageClassSessionChanges) {
    _showMessage(context, '수업 변경은 담당 교사 또는 관리자/스태프만 등록할 수 있습니다.');
    return false;
  }

  final session = findClassSessionById(controller, classSessionId);
  if (session == null) {
    _showMessage(context, '수업 정보를 찾을 수 없습니다.');
    return false;
  }
  final baseSlot = controller.findTimeSlot(session.timeSlotId);
  final termStart = controller.selectedTerm?.startDate;
  final termEnd = controller.selectedTerm?.endDate;

  final defaultDate = _nextOccurrence(
    dayOfWeek: baseSlot?.dayOfWeek ?? _appDayOfWeek(DateTime.now()),
    termStart: termStart,
    termEnd: termEnd,
  );

  var changeType = existing?.changeType ?? 'CANCELED';
  var scope = existing == null
      ? _ChangeScope.singleDay
      : _scopeOf(existing);
  var effectiveFrom = _dateOnly(existing?.effectiveFrom ?? defaultDate);
  var effectiveTo = existing?.effectiveTo == null
      ? null
      : _dateOnly(existing!.effectiveTo!);
  String? newTimeSlotId = existing?.newTimeSlotId;
  String? substituteTeacherId = existing?.substituteTeacherId;

  final locationController = TextEditingController(
    text: existing?.newLocation ?? '',
  );
  final reasonController = TextEditingController(text: existing?.reason ?? '');

  ClassSessionChange? saved;
  try {
    saved = await showDialog<ClassSessionChange>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        var isSaving = false;

        return StatefulBuilder(
          builder: (localContext, setLocalState) {
            final typeOption = _changeTypeOptionOf(changeType);
            final theme = Theme.of(localContext);

            Future<void> pickDate({required bool isEndDate}) async {
              final initial = isEndDate
                  ? (effectiveTo ?? effectiveFrom)
                  : effectiveFrom;
              final picked = await _pickDate(
                context: localContext,
                initialDate: initial,
                termStart: termStart,
                termEnd: termEnd,
                // 하루짜리 변경은 그 수업이 실제로 있는 요일만 고를 수 있게 한다.
                onlyDayOfWeek: scope == _ChangeScope.singleDay
                    ? baseSlot?.dayOfWeek
                    : null,
              );
              if (picked == null) {
                return;
              }
              setLocalState(() {
                if (isEndDate) {
                  effectiveTo = picked;
                } else {
                  effectiveFrom = picked;
                  if (scope == _ChangeScope.singleDay) {
                    effectiveTo = picked;
                  } else if (effectiveTo != null &&
                      effectiveTo!.isBefore(picked)) {
                    effectiveTo = picked;
                  }
                }
              });
            }

            Future<void> save() async {
              final reason = reasonController.text.trim();
              final location = locationController.text.trim();

              if (changeType == 'TIME_MOVED' &&
                  (newTimeSlotId == null || newTimeSlotId!.isEmpty)) {
                _showMessage(localContext, '변경할 교시를 선택하세요.');
                return;
              }
              if (changeType == 'ROOM_MOVED' && location.isEmpty) {
                _showMessage(localContext, '변경할 장소를 입력하세요.');
                return;
              }
              if (changeType == 'TEACHER_SUBSTITUTE' &&
                  (substituteTeacherId == null ||
                      substituteTeacherId!.isEmpty)) {
                _showMessage(localContext, '보강 교사를 선택하세요.');
                return;
              }
              if (changeType == 'NOTE' && reason.isEmpty) {
                _showMessage(localContext, '안내할 내용을 입력하세요.');
                return;
              }
              final until = scope == _ChangeScope.restOfTerm
                  ? null
                  : (scope == _ChangeScope.singleDay
                        ? effectiveFrom
                        : effectiveTo);
              if (until != null && until.isBefore(effectiveFrom)) {
                _showMessage(localContext, '종료일은 시작일보다 빠를 수 없습니다.');
                return;
              }

              setLocalState(() => isSaving = true);
              try {
                final result = existing == null
                    ? await controller.createClassSessionChange(
                        classSessionId: classSessionId,
                        changeType: changeType,
                        effectiveFrom: effectiveFrom,
                        effectiveTo: until,
                        newTimeSlotId: changeType == 'TIME_MOVED'
                            ? newTimeSlotId
                            : null,
                        newLocation: changeType == 'ROOM_MOVED' ? location : '',
                        substituteTeacherId:
                            changeType == 'TEACHER_SUBSTITUTE'
                            ? substituteTeacherId
                            : null,
                        reason: reason,
                      )
                    : await controller.updateClassSessionChange(
                        id: existing.id,
                        changeType: changeType,
                        effectiveFrom: effectiveFrom,
                        effectiveTo: until,
                        newTimeSlotId: changeType == 'TIME_MOVED'
                            ? newTimeSlotId
                            : null,
                        newLocation: changeType == 'ROOM_MOVED' ? location : '',
                        substituteTeacherId:
                            changeType == 'TEACHER_SUBSTITUTE'
                            ? substituteTeacherId
                            : null,
                        reason: reason,
                      );
                if (!localContext.mounted) {
                  return;
                }
                Navigator.of(dialogContext).pop(result);
              } catch (error) {
                if (!localContext.mounted) {
                  return;
                }
                setLocalState(() => isSaving = false);
                _showMessage(
                  localContext,
                  error is StateError ? error.message : controller.statusMessage,
                );
              }
            }

            return AlertDialog(
              title: Text(existing == null ? '수업 변경 등록' : '수업 변경 수정'),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        classSessionHeadline(controller, session),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: NestColors.deepWood.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SelectFieldCard(
                        label: '변경 유형',
                        hintText: '유형을 선택하세요',
                        icon: typeOption.icon,
                        enabled: !isSaving,
                        value: typeOption.label,
                        helpText: typeOption.description,
                        onTap: () async {
                          final selected = await showSelectSheet<String>(
                            context: localContext,
                            title: '변경 유형 선택',
                            helpText: '학생·학부모에게 보낼 문자 문구가 유형에 따라 달라집니다.',
                            options: _changeTypeOptions
                                .map(
                                  (option) => SelectSheetOption<String>(
                                    value: option.value,
                                    title: option.label,
                                    subtitle: option.description,
                                    keywords: '${option.label} ${option.value}',
                                  ),
                                )
                                .toList(),
                            currentValue: changeType,
                          );
                          if (selected == null) {
                            return;
                          }
                          setLocalState(() => changeType = selected);
                        },
                      ),
                      const SizedBox(height: 12),
                      Text('적용 범위', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _scopeChip(
                            label: '이번 주만',
                            selected: scope == _ChangeScope.singleDay,
                            enabled: !isSaving,
                            onSelected: () {
                              setLocalState(() {
                                scope = _ChangeScope.singleDay;
                                effectiveFrom = _alignToDayOfWeek(
                                  effectiveFrom,
                                  baseSlot?.dayOfWeek,
                                );
                                effectiveTo = effectiveFrom;
                              });
                            },
                          ),
                          _scopeChip(
                            label: '학기 남은 기간',
                            selected: scope == _ChangeScope.restOfTerm,
                            enabled: !isSaving,
                            onSelected: () {
                              setLocalState(() {
                                scope = _ChangeScope.restOfTerm;
                                effectiveTo = null;
                              });
                            },
                          ),
                          _scopeChip(
                            label: '기간 지정',
                            selected: scope == _ChangeScope.custom,
                            enabled: !isSaving,
                            onSelected: () {
                              setLocalState(() {
                                scope = _ChangeScope.custom;
                                effectiveTo ??= effectiveFrom;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SelectFieldCard(
                        label: scope == _ChangeScope.singleDay
                            ? '변경 날짜'
                            : '시작일',
                        hintText: '날짜를 선택하세요',
                        icon: Icons.event_outlined,
                        enabled: !isSaving,
                        value: _dateLabel(effectiveFrom),
                        helpText: scope == _ChangeScope.singleDay
                            ? '이 날짜 하루만 변경이 적용됩니다.'
                            : (scope == _ChangeScope.restOfTerm
                                  ? '이 날짜부터 학기가 끝날 때까지 적용됩니다.'
                                  : null),
                        onTap: () => pickDate(isEndDate: false),
                      ),
                      if (scope == _ChangeScope.custom) ...[
                        const SizedBox(height: 8),
                        SelectFieldCard(
                          label: '종료일',
                          hintText: '날짜를 선택하세요',
                          icon: Icons.event_available_outlined,
                          enabled: !isSaving,
                          value: _dateLabel(effectiveTo ?? effectiveFrom),
                          helpText: '종료일까지 포함해서 적용됩니다.',
                          onTap: () => pickDate(isEndDate: true),
                        ),
                      ],
                      if (changeType == 'TIME_MOVED') ...[
                        const SizedBox(height: 10),
                        SelectFieldCard(
                          label: '바뀐 교시',
                          hintText: '교시를 선택하세요',
                          icon: Icons.schedule_outlined,
                          enabled: !isSaving,
                          value: newTimeSlotId == null
                              ? null
                              : timeSlotLabel(
                                  controller.findTimeSlot(newTimeSlotId!),
                                ),
                          helpText: '옮겨서 진행할 교시를 고르세요.',
                          onTap: () async {
                            final slots = controller.timeSlots.toList()
                              ..sort((a, b) {
                                final day = a.dayOfWeek.compareTo(b.dayOfWeek);
                                if (day != 0) {
                                  return day;
                                }
                                return a.startTime.compareTo(b.startTime);
                              });
                            final selected = await showSelectSheet<String>(
                              context: localContext,
                              title: '바뀐 교시 선택',
                              helpText: '학기에 등록된 교시 중에서 고릅니다.',
                              options: slots
                                  .map(
                                    (slot) => SelectSheetOption<String>(
                                      value: slot.id,
                                      title: timeSlotLabel(slot),
                                      keywords: timeSlotLabel(slot),
                                    ),
                                  )
                                  .toList(),
                              currentValue: newTimeSlotId,
                            );
                            if (selected == null) {
                              return;
                            }
                            setLocalState(() => newTimeSlotId = selected);
                          },
                        ),
                      ],
                      if (changeType == 'ROOM_MOVED') ...[
                        const SizedBox(height: 10),
                        TextField(
                          controller: locationController,
                          enabled: !isSaving,
                          decoration: const InputDecoration(
                            labelText: '바뀐 장소',
                            hintText: '예: 3층 다목적실',
                            prefixIcon: Icon(Icons.meeting_room_outlined),
                          ),
                        ),
                      ],
                      if (changeType == 'TEACHER_SUBSTITUTE') ...[
                        const SizedBox(height: 10),
                        SelectFieldCard(
                          label: '보강 교사',
                          hintText: '교사를 선택하세요',
                          icon: Icons.person_outline,
                          enabled: !isSaving,
                          value: substituteTeacherId == null
                              ? null
                              : controller.findTeacherName(
                                  substituteTeacherId!,
                                ),
                          helpText: '대신 수업에 들어갈 선생님을 고르세요.',
                          onTap: () async {
                            final selected = await showSelectSheet<String>(
                              context: localContext,
                              title: '보강 교사 선택',
                              helpText: '검색으로 선생님을 빠르게 찾을 수 있습니다.',
                              options: controller.teacherProfiles
                                  .map(
                                    (teacher) => SelectSheetOption<String>(
                                      value: teacher.id,
                                      title: teacher.displayName,
                                      subtitle: teacher.teacherType,
                                      keywords:
                                          '${teacher.displayName} ${teacher.teacherType}',
                                    ),
                                  )
                                  .toList(),
                              currentValue: substituteTeacherId,
                            );
                            if (selected == null) {
                              return;
                            }
                            setLocalState(() => substituteTeacherId = selected);
                          },
                        ),
                      ],
                      const SizedBox(height: 10),
                      TextField(
                        controller: reasonController,
                        enabled: !isSaving,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: '사유 / 안내 문구',
                          hintText: '학생·학부모에게 함께 전달할 내용을 적어주세요.',
                          prefixIcon: Icon(Icons.edit_note),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: isSaving ? null : save,
                  child: Text(existing == null ? '등록' : '수정'),
                ),
              ],
            );
          },
        );
      },
    );
  } finally {
    locationController.dispose();
    reasonController.dispose();
  }

  if (saved == null) {
    return false;
  }
  if (!context.mounted) {
    return true;
  }
  _showMessage(context, controller.statusMessage);
  if (!context.mounted) {
    return true;
  }
  await confirmAndNotifyClassChange(
    context: context,
    controller: controller,
    change: saved,
  );
  return true;
}

/// 발송 확인 → 발송. **확인 없이 절대 보내지 않는다.**
Future<void> confirmAndNotifyClassChange({
  required BuildContext context,
  required NestController controller,
  required ClassSessionChange change,
}) async {
  final session = findClassSessionById(controller, change.classSessionId);
  final studentCount = session == null
      ? 0
      : controller.childrenForClassGroup(session.classGroupId).length;
  final isResend = change.isNotified;

  final buffer = StringBuffer();
  buffer.writeln(
    isResend
        ? '이미 한 번 발송한 수업 변경입니다. 같은 내용을 다시 보낼까요?'
        : '이 반 학생·학부모에게 문자로 알릴까요?',
  );
  buffer.writeln();
  if (studentCount > 0) {
    buffer.writeln('대상: 수강생 $studentCount명과 보호자');
  } else {
    buffer.writeln('대상: 이 반 학생과 보호자');
  }
  buffer.write('문자 요금이 실제로 발생하며 되돌릴 수 없습니다.');

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(isResend ? '알림 재발송' : '알림 발송'),
      content: Text(buffer.toString()),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('나중에'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(isResend ? '재발송' : '문자 보내기'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) {
    return;
  }

  try {
    final result = await controller.notifyClassChange(
      changeId: change.id,
      force: isResend,
    );
    if (!context.mounted) {
      return;
    }
    _showMessage(
      context,
      controller.statusMessage,
      isFailure: result.sent <= 0,
    );
  } catch (error) {
    if (!context.mounted) {
      return;
    }
    _showMessage(
      context,
      error is StateError ? error.message : controller.statusMessage,
      isFailure: true,
    );
  }
}

/// 변경 1건을 카드로 그린다. 시트와 교사 허브 목록에서 함께 쓴다.
class ClassSessionChangeTile extends StatelessWidget {
  const ClassSessionChangeTile({
    super.key,
    required this.controller,
    required this.change,
    this.showSessionName = true,
  });

  final NestController controller;
  final ClassSessionChange change;

  /// 여러 수업이 섞이는 목록에서는 수업/반 이름을 함께 보여준다.
  final bool showSessionName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final option = _changeTypeOptionOf(change.changeType);
    final session = findClassSessionById(controller, change.classSessionId);
    final detail = classSessionChangeDetailLabel(controller, change);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NestColors.roseMist),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(option.icon, size: 20, color: NestColors.clay),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      option.label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _statusChip(
                      context,
                      label: change.isNotified ? '발송됨' : '미발송',
                      highlight: change.isNotified,
                    ),
                  ],
                ),
                if (showSessionName && session != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    classSessionHeadline(controller, session),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: NestColors.clay,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 3),
                Text(
                  classSessionChangeRangeLabel(change),
                  style: theme.textTheme.bodySmall,
                ),
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(detail, style: theme.textTheme.bodyMedium),
                ],
                if (change.reason.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    change.reason.trim(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: NestColors.deepWood.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            enabled: !controller.isBusy,
            icon: const Icon(Icons.more_vert, size: 20),
            onSelected: (value) => _handleMenu(context, value),
            itemBuilder: (menuContext) => [
              PopupMenuItem<String>(
                value: 'notify',
                child: Text(change.isNotified ? '알림 재발송' : '알림 보내기'),
              ),
              const PopupMenuItem<String>(value: 'edit', child: Text('수정')),
              const PopupMenuItem<String>(value: 'delete', child: Text('삭제')),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleMenu(BuildContext context, String action) async {
    switch (action) {
      case 'notify':
        await confirmAndNotifyClassChange(
          context: context,
          controller: controller,
          change: change,
        );
        return;
      case 'edit':
        await showClassSessionChangeEditor(
          context: context,
          controller: controller,
          classSessionId: change.classSessionId,
          existing: change,
        );
        return;
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('수업 변경 삭제'),
            content: const Text(
              '등록한 수업 변경을 삭제합니다.\n이미 보낸 문자는 취소되지 않습니다.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('삭제'),
              ),
            ],
          ),
        );
        if (confirmed != true || !context.mounted) {
          return;
        }
        try {
          await controller.deleteClassSessionChange(id: change.id);
          if (!context.mounted) {
            return;
          }
          _showMessage(context, controller.statusMessage);
        } catch (error) {
          if (!context.mounted) {
            return;
          }
          _showMessage(
            context,
            error is StateError ? error.message : controller.statusMessage,
            isFailure: true,
          );
        }
        return;
    }
  }
}

// ---------------------------------------------------------------------------
// 공용 라벨/조회 헬퍼
// ---------------------------------------------------------------------------

/// 세션 id 로 [ClassSession] 을 찾는다. 학기 전체 목록을 먼저 본다.
ClassSession? findClassSessionById(NestController controller, String id) {
  if (id.isEmpty) {
    return null;
  }
  return controller.allTermSessions.where((row) => row.id == id).firstOrNull ??
      controller.sessions.where((row) => row.id == id).firstOrNull;
}

/// "과목 · 반 · 월 09:00-10:00" 한 줄 요약.
String classSessionHeadline(NestController controller, ClassSession session) {
  final course = session.title.trim().isEmpty
      ? controller.findCourseName(session.courseId)
      : session.title.trim();
  final className = controller.findClassGroupName(session.classGroupId);
  final slotLabel = timeSlotLabel(controller.findTimeSlot(session.timeSlotId));
  final parts = <String>[
    course,
    if (className.trim().isNotEmpty) className,
    if (slotLabel.isNotEmpty) slotLabel,
  ];
  return parts.join(' · ');
}

/// "월 09:00-10:00" 형태의 교시 라벨.
String timeSlotLabel(TimeSlot? slot) {
  if (slot == null) {
    return '';
  }
  return '${dayLabel(slot.dayOfWeek)} '
      '${_shortTime(slot.startTime)}-${_shortTime(slot.endTime)}';
}

/// 앱 규약: 0 = 일요일.
String dayLabel(int dayOfWeek) {
  const labels = <int, String>{
    0: '일',
    1: '월',
    2: '화',
    3: '수',
    4: '목',
    5: '금',
    6: '토',
  };
  return labels[dayOfWeek] ?? '$dayOfWeek';
}

/// 적용 기간을 사람이 읽는 문장으로.
String classSessionChangeRangeLabel(ClassSessionChange change) {
  final from = _dateOnly(change.effectiveFrom);
  final to = change.effectiveTo;
  if (to == null) {
    return '${_dateLabel(from)}부터 학기 끝까지';
  }
  final until = _dateOnly(to);
  if (until == from) {
    return '${_dateLabel(from)} 하루만';
  }
  return '${_dateLabel(from)} ~ ${_dateLabel(until)}';
}

/// 유형별 추가 정보("바뀐 교시 · 장소 · 보강 교사"). 없으면 빈 문자열.
String classSessionChangeDetailLabel(
  NestController controller,
  ClassSessionChange change,
) {
  switch (change.changeType) {
    case 'TIME_MOVED':
      final slot = change.newTimeSlotId == null
          ? null
          : controller.findTimeSlot(change.newTimeSlotId!);
      final label = timeSlotLabel(slot);
      return label.isEmpty ? '' : '바뀐 교시: $label';
    case 'ROOM_MOVED':
      final location = change.newLocation.trim();
      return location.isEmpty ? '' : '바뀐 장소: $location';
    case 'TEACHER_SUBSTITUTE':
      final teacherId = change.substituteTeacherId;
      if (teacherId == null || teacherId.isEmpty) {
        return '';
      }
      return '보강 교사: ${controller.findTeacherName(teacherId)}';
    default:
      return '';
  }
}

// ---------------------------------------------------------------------------
// private
// ---------------------------------------------------------------------------

_ChangeScope _scopeOf(ClassSessionChange change) {
  final to = change.effectiveTo;
  if (to == null) {
    return _ChangeScope.restOfTerm;
  }
  return _dateOnly(to) == _dateOnly(change.effectiveFrom)
      ? _ChangeScope.singleDay
      : _ChangeScope.custom;
}

Widget _scopeChip({
  required String label,
  required bool selected,
  required bool enabled,
  required VoidCallback onSelected,
}) {
  return ChoiceChip(
    label: Text(label),
    selected: selected,
    onSelected: enabled ? (_) => onSelected() : null,
  );
}

Widget _statusChip(
  BuildContext context, {
  required String label,
  required bool highlight,
}) {
  final color = highlight ? NestColors.mutedSage : NestColors.clay;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(999),
      color: color.withValues(alpha: 0.14),
      border: Border.all(color: color.withValues(alpha: 0.5)),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
        fontSize: 11,
      ),
    ),
  );
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// 앱 규약(0=일)으로 변환한 요일. Dart 는 1=월 … 7=일 이라 % 7 하면 맞아떨어진다.
int _appDayOfWeek(DateTime date) => date.weekday % 7;

/// [dayOfWeek] 요일의 다가오는 회차(오늘 포함). 학기 범위 안으로 잘라낸다.
DateTime _nextOccurrence({
  required int dayOfWeek,
  DateTime? termStart,
  DateTime? termEnd,
}) {
  var cursor = _dateOnly(DateTime.now());
  if (termStart != null) {
    final start = _dateOnly(termStart);
    if (cursor.isBefore(start)) {
      cursor = start;
    }
  }
  for (var i = 0; i < 7; i++) {
    if (_appDayOfWeek(cursor) == dayOfWeek) {
      break;
    }
    cursor = cursor.add(const Duration(days: 1));
  }
  if (termEnd != null) {
    final end = _dateOnly(termEnd);
    if (cursor.isAfter(end)) {
      return end;
    }
  }
  return cursor;
}

/// [date] 를 [dayOfWeek] 요일에 맞춰 같은 주 안에서 옮긴다.
DateTime _alignToDayOfWeek(DateTime date, int? dayOfWeek) {
  if (dayOfWeek == null) {
    return _dateOnly(date);
  }
  var cursor = _dateOnly(date);
  for (var i = 0; i < 7; i++) {
    if (_appDayOfWeek(cursor) == dayOfWeek) {
      return cursor;
    }
    cursor = cursor.add(const Duration(days: 1));
  }
  return _dateOnly(date);
}

Future<DateTime?> _pickDate({
  required BuildContext context,
  required DateTime initialDate,
  DateTime? termStart,
  DateTime? termEnd,
  int? onlyDayOfWeek,
}) async {
  final today = _dateOnly(DateTime.now());
  var first = _dateOnly(termStart ?? today.subtract(const Duration(days: 365)));
  var last = _dateOnly(termEnd ?? today.add(const Duration(days: 365)));
  final initial = _dateOnly(initialDate);
  if (initial.isBefore(first)) {
    first = initial;
  }
  if (initial.isAfter(last)) {
    last = initial;
  }
  if (last.isBefore(first)) {
    last = first;
  }

  return showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: first,
    lastDate: last,
    helpText: '날짜 선택',
    cancelText: '취소',
    confirmText: '확인',
    selectableDayPredicate: onlyDayOfWeek == null
        ? null
        : (day) => _appDayOfWeek(day) == onlyDayOfWeek,
  );
}

String _dateLabel(DateTime date) {
  return '${DateFormat('yyyy-MM-dd').format(date)}(${dayLabel(_appDayOfWeek(date))})';
}

String _shortTime(String value) {
  final parts = value.trim().split(':');
  if (parts.length < 2) {
    return value;
  }
  final hour = parts[0].padLeft(2, '0');
  final minute = parts[1].padLeft(2, '0');
  return '$hour:$minute';
}

void _showMessage(
  BuildContext context,
  String text, {
  bool isFailure = false,
}) {
  if (!context.mounted || text.trim().isEmpty) {
    return;
  }
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) {
    return;
  }
  messenger.showSnackBar(
    SnackBar(
      content: Text(text),
      backgroundColor: isFailure
          ? Theme.of(context).colorScheme.error
          : null,
    ),
  );
}
