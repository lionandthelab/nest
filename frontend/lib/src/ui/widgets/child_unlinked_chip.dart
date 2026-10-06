import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../state/nest_controller.dart';
import '../nest_theme.dart';
import 'nest_sheet.dart';

/// 학부모 계정에 연결된 아이가 없을 때 헤더에 보이는 칩.
/// 탭하면 연결 안내와 함께 '내 아이 등록 요청' 시트를 연다.
class ChildUnlinkedChip extends StatelessWidget {
  const ChildUnlinkedChip({
    super.key,
    required this.controller,
    this.label = '아이 미연동',
  });

  final NestController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      tooltip: '내 아이 연결',
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w600,
        ),
      ),
      avatar: const Icon(
        Icons.child_friendly_outlined,
        size: 14,
        color: Colors.black87,
      ),
      visualDensity: VisualDensity.compact,
      onPressed: () => showChildRegistrationRequestSheet(
        context: context,
        controller: controller,
      ),
    );
  }
}

/// 관리자에게 아이 등록을 요청하는 시트. 승인되면 이 계정이 그 가정의
/// 보호자로 연결되어 아이 선택기에 아이가 나타난다.
Future<void> showChildRegistrationRequestSheet({
  required BuildContext context,
  required NestController controller,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final submitted = await showNestSheet<bool>(
    context: context,
    builder: (_) => _ChildRegistrationRequestSheet(controller: controller),
  );
  if (submitted == true) {
    messenger?.showSnackBar(SnackBar(content: Text(controller.statusMessage)));
  }
}

class _ChildRegistrationRequestSheet extends StatefulWidget {
  const _ChildRegistrationRequestSheet({required this.controller});

  final NestController controller;

  @override
  State<_ChildRegistrationRequestSheet> createState() =>
      _ChildRegistrationRequestSheetState();
}

class _ChildRegistrationRequestSheetState
    extends State<_ChildRegistrationRequestSheet> {
  final _familyNameCtrl = TextEditingController();
  final _childNameCtrl = TextEditingController();
  DateTime? _birthDate;
  String? _error;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final fullName = widget.controller.user?.userMetadata?['full_name'];
    if (fullName is String && fullName.trim().isNotEmpty) {
      _familyNameCtrl.text = '${fullName.trim()} 가정';
    }
  }

  @override
  void dispose() {
    _familyNameCtrl.dispose();
    _childNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(2018, 1, 1),
      firstDate: DateTime(2005),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _birthDate = picked);
    }
  }

  Future<void> _submit() async {
    final familyName = _familyNameCtrl.text.trim();
    final childName = _childNameCtrl.text.trim();
    if (familyName.isEmpty || childName.isEmpty) {
      setState(() => _error = '가정 이름과 아이 이름을 입력하세요.');
      return;
    }

    setState(() {
      _error = null;
      _isSubmitting = true;
    });
    try {
      await widget.controller.requestChildRegistration(
        familyName: familyName,
        childName: childName,
        birthDate: _birthDate == null
            ? null
            : DateFormat('yyyy-MM-dd').format(_birthDate!),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      final message = error is StateError
          ? error.message
          : widget.controller.statusMessage;
      setState(() {
        _isSubmitting = false;
        _error = message.isEmpty ? '요청을 보내지 못했습니다. 다시 시도해 주세요.' : message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return NestSheet(
      title: '내 아이 등록 요청',
      icon: Icons.child_care_outlined,
      isBusy: _isSubmitting,
      actions: [
        OutlinedButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: const Text('요청 보내기'),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: NestColors.roseMist.withValues(alpha: 0.36),
            ),
            child: Text(
              '아직 이 계정에 연결된 아이가 없어요.\n'
              '홈스쿨 관리자가 가정에 보호자로 연결해 주면 아이가 바로 보여요. '
              '아래에서 직접 등록을 요청할 수도 있어요.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _familyNameCtrl,
            decoration: const InputDecoration(
              labelText: '가정 이름',
              hintText: '예: 홍길동 가정',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _childNameCtrl,
            decoration: const InputDecoration(
              labelText: '아이 이름',
              hintText: '예: 홍길순',
            ),
          ),
          const SizedBox(height: 4),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              _birthDate == null
                  ? '생년월일 (선택)'
                  : DateFormat('yyyy-MM-dd').format(_birthDate!),
            ),
            trailing: const Icon(Icons.calendar_today, size: 18),
            onTap: _isSubmitting ? null : _pickBirthDate,
          ),
          if (_error != null) ...[
            const SizedBox(height: 4),
            Text(
              _error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
