import 'package:flutter/material.dart';

import '../../../models/nest_models.dart';
import '../../../state/nest_controller.dart';
import '../../nest_theme.dart';

/// Opens the "가정·학생 반 배정" dialog: drag a student card onto a class
/// drop-zone to enroll. Reads/mutates [NestController] only.
Future<void> showFamilyEnrollmentDialog(
  BuildContext context,
  NestController controller,
) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960, maxHeight: 640),
          child: SizedBox(
            width: 960,
            height: 640,
            child: FamilyEnrollmentPanel(controller: controller),
          ),
        ),
      );
    },
  );
}

/// Drag-to-enroll panel pairing 가정별 학생 카드 with 반 드롭존.
///
/// - Top row: one [DragTarget] per class group (drop a child to enroll).
/// - Below: one card per family with its children as [Draggable] chips, each
///   showing removable mini-chips of the child's current class assignments.
/// - Multi-select bar bulk-adds the selected children to a chosen class via
///   [NestController.syncClassEnrollments] (union with existing enrollment).
class FamilyEnrollmentPanel extends StatefulWidget {
  const FamilyEnrollmentPanel({
    super.key,
    required this.controller,
  });

  final NestController controller;

  @override
  State<FamilyEnrollmentPanel> createState() => _FamilyEnrollmentPanelState();
}

class _FamilyEnrollmentPanelState extends State<FamilyEnrollmentPanel> {
  // Multi-select bulk state.
  final Set<String> _selectedChildIds = <String>{};
  String? _bulkClassGroupId;

  bool get _locked =>
      widget.controller.isBusy || widget.controller.isSelectedTermArchived;

  void _toggleSelected(String childId) {
    setState(() {
      if (_selectedChildIds.contains(childId)) {
        _selectedChildIds.remove(childId);
      } else {
        _selectedChildIds.add(childId);
      }
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    final text = message.replaceFirst('Exception: ', '');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> _enrollChild(String classGroupId, String childId) async {
    final controller = widget.controller;
    if (controller.isChildEnrolledInClass(
      classGroupId: classGroupId,
      childId: childId,
    )) {
      _showMessage('이미 해당 반에 배정되어 있습니다.');
      return;
    }
    try {
      await controller.assignChildToClass(
        classGroupId: classGroupId,
        childId: childId,
      );
    } on StateError catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage(controller.statusMessage);
    }
  }

  Future<void> _unenrollChild(String classGroupId, String childId) async {
    try {
      await widget.controller.unassignChildFromClass(
        classGroupId: classGroupId,
        childId: childId,
      );
    } on StateError catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  Future<void> _bulkAssign() async {
    final controller = widget.controller;
    final classGroupId = _bulkClassGroupId;
    if (classGroupId == null || _selectedChildIds.isEmpty) {
      return;
    }
    // ADD the selected children to the class without removing others: union
    // existing enrolled with the new selection, then sync to that set.
    final union = <String>{
      ...controller.enrolledChildIdsForClassGroup(classGroupId),
      ..._selectedChildIds,
    };
    try {
      await controller.syncClassEnrollments(
        classGroupId: classGroupId,
        childIds: union,
      );
      if (mounted) {
        setState(_selectedChildIds.clear);
      }
    } on StateError catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage(controller.statusMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const Divider(height: 1),
            Expanded(
              child: controller.canManageFamilies
                  ? _buildBody(context, controller)
                  : _buildReadOnlyNotice(context),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
      child: Row(
        children: [
          Icon(Icons.family_restroom, color: NestColors.dustyRose),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '가정·학생 반 배정',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: '닫기',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyNotice(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              size: 36,
              color: NestColors.clay,
            ),
            const SizedBox(height: 12),
            Text(
              '가정·학생 반 배정은 관리자/스태프만 가능합니다.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: NestColors.deepWood.withValues(alpha: 0.72),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, NestController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (controller.isSelectedTermArchived) _buildArchivedBanner(context),
        _buildDropZoneRow(context, controller),
        _buildBulkActionBar(context, controller),
        Expanded(
          child: _buildFamilyGrid(context, controller),
        ),
      ],
    );
  }

  Widget _buildArchivedBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: NestColors.roseMist.withValues(alpha: 0.6),
        border: Border.all(color: NestColors.clay),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 18, color: NestColors.clay),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '보관됨(ARCHIVED) 학기입니다. 반 배정을 변경할 수 없습니다.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: NestColors.deepWood.withValues(alpha: 0.8),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Top: class drop-zone row -------------------------------------------

  Widget _buildDropZoneRow(BuildContext context, NestController controller) {
    final classGroups = controller.classGroups.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    if (classGroups.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
        child: Text(
          '등록된 반이 없습니다. 먼저 반을 만들어 주세요.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.6),
              ),
        ),
      );
    }

    return Container(
      height: 116,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: classGroups.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          return _buildClassDropTarget(context, controller, classGroups[index]);
        },
      ),
    );
  }

  Widget _buildClassDropTarget(
    BuildContext context,
    NestController controller,
    ClassGroup group,
  ) {
    final enrolledCount =
        controller.enrolledChildIdsForClassGroup(group.id).length;
    final isSelectedClass = controller.selectedClassGroupId == group.id;

    return DragTarget<String>(
      onWillAcceptWithDetails: (_) => !_locked,
      onAcceptWithDetails: (details) => _enrollChild(group.id, details.data),
      builder: (context, candidateData, rejectedData) {
        final hovering = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 180,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: hovering ? NestColors.roseMist : Colors.white,
            border: Border.all(
              color: hovering ? NestColors.dustyRose : NestColors.roseMist,
              width: hovering ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (isSelectedClass) ...[
                    Icon(
                      Icons.circle,
                      size: 10,
                      color: NestColors.dustyRose,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      group.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Icon(
                    Icons.school_outlined,
                    size: 16,
                    color: NestColors.mutedSage,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '학생 $enrolledCount명',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: NestColors.deepWood.withValues(alpha: 0.8),
                        ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Multi-select bulk action bar ---------------------------------------

  Widget _buildBulkActionBar(BuildContext context, NestController controller) {
    if (_selectedChildIds.isEmpty) {
      return const SizedBox.shrink();
    }

    final classGroups = controller.classGroups.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final bulkValue =
        classGroups.any((g) => g.id == _bulkClassGroupId) ? _bulkClassGroupId : null;
    final canAssign = !_locked && bulkValue != null;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: NestColors.roseMist.withValues(alpha: 0.5),
        border: Border.all(color: NestColors.dustyRose),
      ),
      child: Row(
        children: [
          Flexible(
            child: Text(
              '선택한 ${_selectedChildIds.length}명을 반에 배정',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<String?>(
              initialValue: bulkValue,
              isDense: true,
              decoration: const InputDecoration(
                labelText: '반 선택',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: classGroups
                  .map(
                    (group) => DropdownMenuItem<String?>(
                      value: group.id,
                      child: Text(group.name),
                    ),
                  )
                  .toList(),
              onChanged: _locked
                  ? null
                  : (value) => setState(() => _bulkClassGroupId = value),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: canAssign ? _bulkAssign : null,
            icon: const Icon(Icons.playlist_add_check, size: 18),
            label: const Text('배정'),
          ),
          IconButton(
            tooltip: '선택 해제',
            onPressed: _locked
                ? null
                : () => setState(_selectedChildIds.clear),
            icon: const Icon(Icons.clear),
          ),
        ],
      ),
    );
  }

  // --- Below: family cards with draggable children ------------------------

  Widget _buildFamilyGrid(BuildContext context, NestController controller) {
    final families = controller.families.toList()
      ..sort((a, b) => a.familyName.compareTo(b.familyName));

    if (families.isEmpty) {
      return Center(
        child: Text(
          '등록된 가정이 없습니다.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.6),
              ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: families
            .map((family) => _buildFamilyCard(context, controller, family))
            .toList(),
      ),
    );
  }

  Widget _buildFamilyCard(
    BuildContext context,
    NestController controller,
    Family family,
  ) {
    final children = controller.childrenForFamily(family.id)
      ..sort((a, b) => a.name.compareTo(b.name));

    return Container(
      width: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: NestColors.creamyWhite,
        border: Border.all(color: NestColors.roseMist),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Icon(
                  Icons.home_outlined,
                  size: 18,
                  color: NestColors.clay,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    family.familyName,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: children.isEmpty
                ? Text(
                    '자녀 없음',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: NestColors.deepWood.withValues(alpha: 0.5),
                        ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: children
                        .map((child) =>
                            _buildChildTile(context, controller, child))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildChildTile(
    BuildContext context,
    NestController controller,
    ChildProfile child,
  ) {
    final assignments = controller.classGroupsForChild(child.id);
    final selected = _selectedChildIds.contains(child.id);

    final tile = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: selected ? NestColors.roseMist : Colors.white,
        border: Border.all(
          color: selected ? NestColors.dustyRose : NestColors.roseMist,
          width: selected ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: selected,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: _locked
                    ? null
                    : (_) => _toggleSelected(child.id),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  child.name,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              Icon(
                Icons.drag_indicator,
                size: 18,
                color: NestColors.deepWood.withValues(alpha: 0.4),
              ),
            ],
          ),
          if (assignments.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: assignments
                  .map((group) => _buildAssignmentChip(context, group, child))
                  .toList(),
            ),
          ],
        ],
      ),
    );

    return Draggable<String>(
      data: child.id,
      maxSimultaneousDrags: _locked ? 0 : null,
      // The full tile carries selection + assignment chips; while dragging we
      // surface a compact chip with just the child name.
      feedback: Material(
        color: Colors.transparent,
        child: _ChildDragChip(name: child.name, dragging: true),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: tile),
      child: _locked
          ? tile
          : MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: tile,
            ),
    );
  }

  Widget _buildAssignmentChip(
    BuildContext context,
    ClassGroup group,
    ChildProfile child,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 3, 4, 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: NestColors.mutedSage.withValues(alpha: 0.18),
        border: Border.all(
          color: NestColors.mutedSage.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            group.name,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: NestColors.deepWood,
                ),
          ),
          const SizedBox(width: 2),
          InkWell(
            onTap: _locked
                ? null
                : () => _unenrollChild(group.id, child.id),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(
                Icons.close,
                size: 14,
                color: NestColors.deepWood.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact drag feedback chip showing a child's name.
class _ChildDragChip extends StatelessWidget {
  const _ChildDragChip({
    required this.name,
    this.dragging = false,
  });

  final String name;
  final bool dragging;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: NestColors.dustyRose,
        boxShadow: dragging
            ? const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.person, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
