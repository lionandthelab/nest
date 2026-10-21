import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nest_frontend/src/models/nest_models.dart';
import 'package:nest_frontend/src/services/nest_repository.dart';
import 'package:nest_frontend/src/state/nest_controller.dart';
import 'package:nest_frontend/src/ui/nest_theme.dart';
import 'package:nest_frontend/src/ui/widgets/homeschool_chat_view.dart';

class _FakeChatController extends NestController {
  _FakeChatController()
    : super(
        repository: NestRepository(
          SupabaseClient(
            'http://localhost',
            'test-key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          ),
        ),
      ) {
    selectedHomeschoolId = 'hs-1';
    currentRole = 'HOMESCHOOL_ADMIN';
    classGroups = const [
      ClassGroup(id: 'cg-1', termId: 't-1', name: '소망반', capacity: 12),
    ];
    courses = const [
      Course(
        id: 'course-1',
        homeschoolId: 'hs-1',
        name: '창의 과학 실험',
        defaultDurationMin: 50,
      ),
    ];
    timeSlots = const [
      TimeSlot(
        id: 'slot-1',
        termId: 't-1',
        dayOfWeek: 3,
        startTime: '10:00:00',
        endTime: '10:50:00',
      ),
    ];
    allTermSessions = const [
      ClassSession(
        id: 'sess-1',
        classGroupId: 'cg-1',
        courseId: 'course-1',
        timeSlotId: 'slot-1',
        title: '창의 과학 실험',
        sourceType: 'MANUAL',
        status: 'PLANNED',
        location: '과학실',
      ),
    ];
    teacherProfiles = const [
      TeacherProfile(
        id: 'tp-1',
        homeschoolId: 'hs-1',
        userId: 'user-teacher-1',
        displayName: '김민지 선생님',
        teacherType: 'TEACHER',
        specialties: ['과학'],
        bio: '수요일 오전 과학 실험 담당',
        createdAt: null,
      ),
    ];
  }

  int _nextId = 1;

  @override
  Future<void> ensureChatMessages({bool force = false}) async {}

  @override
  Future<void> refreshChatMessages() async {}

  @override
  Future<HomeschoolChatMessage> sendChatMessage({
    required String content,
    String? classGroupId,
    String? recipientUserId,
    List<PendingMediaFile> files = const [],
  }) async {
    final created = HomeschoolChatMessage(
      id: 'msg-${_nextId++}',
      homeschoolId: 'hs-1',
      classGroupId: classGroupId,
      recipientUserId: recipientUserId,
      senderUserId: 'me-1',
      senderName: '하준 어머니',
      senderRole: 'PARENT',
      messageType: 'TEXT',
      content: content,
      attachments: const [],
      createdAt: DateTime(2026, 10, 20, 10, 30),
    );
    chatMessages = [...chatMessages, created];
    notifyListeners();
    return created;
  }

  @override
  Future<HomeschoolChatMessage> sendScheduleChatMessage({
    required SharedScheduleInfo schedule,
    String caption = '',
    String? classGroupId,
    String? recipientUserId,
  }) async {
    final created = HomeschoolChatMessage(
      id: 'msg-${_nextId++}',
      homeschoolId: 'hs-1',
      classGroupId: classGroupId,
      recipientUserId: recipientUserId,
      senderUserId: 'me-1',
      senderName: '하준 어머니',
      senderRole: 'PARENT',
      messageType: 'SCHEDULE',
      content: caption.trim().isNotEmpty ? caption.trim() : schedule.title,
      sharedSchedule: schedule,
      createdAt: DateTime(2026, 10, 20, 10, 31),
    );
    chatMessages = [...chatMessages, created];
    notifyListeners();
    return created;
  }

  @override
  Future<HomeschoolChatMessage> sendContactChatMessage({
    required SharedContactInfo contact,
    String caption = '',
    String? classGroupId,
    String? recipientUserId,
  }) async {
    final created = HomeschoolChatMessage(
      id: 'msg-${_nextId++}',
      homeschoolId: 'hs-1',
      classGroupId: classGroupId,
      recipientUserId: recipientUserId,
      senderUserId: 'me-1',
      senderName: '하준 어머니',
      senderRole: 'PARENT',
      messageType: 'CONTACT',
      content: caption.trim().isNotEmpty ? caption.trim() : contact.contactName,
      sharedContact: contact,
      createdAt: DateTime(2026, 10, 20, 10, 32),
    );
    chatMessages = [...chatMessages, created];
    notifyListeners();
    return created;
  }
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko_KR');
  });

  testWidgets(
    'HomeschoolChatView sends text, shares schedule & contact cards, and switches rooms',
    (tester) async {
      final controller = _FakeChatController();
      await tester.pumpWidget(
        MaterialApp(
          theme: NestTheme.light(),
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 700,
              child: HomeschoolChatView(controller: controller),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 빈 채팅 안내 및 퀵 공유 칩 확인
      expect(find.text('첫 대화를 시작해 보세요'), findsOneWidget);
      expect(find.byKey(const ValueKey('chat-share-photo')), findsOneWidget);
      expect(find.byKey(const ValueKey('chat-share-video')), findsOneWidget);
      expect(find.byKey(const ValueKey('chat-share-schedule')), findsOneWidget);
      expect(find.byKey(const ValueKey('chat-share-contact')), findsOneWidget);

      // 1. 일반 텍스트 메시지 전송
      await tester.enterText(
        find.byKey(const ValueKey('chat-message-input')),
        '안녕하세요! 오늘 준비물 공유드립니다.',
      );
      await tester.tap(find.byKey(const ValueKey('chat-send-button')));
      await tester.pumpAndSettle();

      expect(find.text('안녕하세요! 오늘 준비물 공유드립니다.'), findsOneWidget);

      // 2. 스케줄 원클릭 공유 시트 열기 및 시간표 수업 공유
      await tester.tap(find.byKey(const ValueKey('chat-share-schedule')));
      await tester.pumpAndSettle();

      expect(find.text('스케줄 공유하기'), findsOneWidget);
      expect(find.text('창의 과학 실험'), findsOneWidget);

      await tester.tap(find.text('창의 과학 실험'));
      await tester.pumpAndSettle();

      // 채팅방에 스케줄 카드가 렌더링됨
      expect(find.text('수업 시간표'), findsOneWidget);
      expect(find.text('내 일정에 담기'), findsOneWidget);

      // 3. 연락처 원클릭 공유 시트 열기 및 교사 연락처 공유
      await tester.tap(find.byKey(const ValueKey('chat-share-contact')));
      await tester.pumpAndSettle();

      expect(find.text('연락처 공유하기'), findsOneWidget);
      expect(find.text('김민지 선생님'), findsOneWidget);

      await tester.tap(find.text('김민지 선생님'));
      await tester.pumpAndSettle();

      // 채팅방에 연락처 카드가 렌더링됨
      expect(find.text('수요일 오전 과학 실험 담당'), findsOneWidget);

      // 4. 반별 단톡방(소망반) 전환 시 필터링 확인
      await tester.tap(find.byKey(const ValueKey('chat-room-class-cg-1')));
      await tester.pumpAndSettle();

      expect(find.text('첫 대화를 시작해 보세요'), findsOneWidget);
    },
  );
}
