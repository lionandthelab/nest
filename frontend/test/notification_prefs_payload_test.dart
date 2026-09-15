// 알림 설정 저장 페이로드.
//
// 웹은 main 푸시로 바로 배포되고 마이그레이션은 따로 돌린다. 그 사이에 새 컬럼을
// 담아 보내면 서버가 42703(undefined_column)으로 튕겨서, 마이그레이션이 끝날
// 때까지 아무도 알림 설정을 저장하지 못한다. 그래서 새 컬럼을 뺀 페이로드로
// 한 번 더 시도한다.

import 'package:flutter_test/flutter_test.dart';

import 'package:nest_frontend/src/models/nest_models.dart';
import 'package:nest_frontend/src/services/nest_repository.dart';

void main() {
  test('기본 페이로드에는 새 컬럼이 들어간다', () {
    const prefs = NotificationPrefs(classReminderLeadMin: 20);
    final map = prefs.toMap();
    expect(map['class_reminder_lead_min'], 20);
    expect(map.containsKey('quiet_hours_start'), isTrue);
  });

  test('폴백 페이로드는 마이그레이션 전 컬럼만 남긴다', () {
    const prefs = NotificationPrefs(
      classReminderLeadMin: 60,
      quietHoursStart: '22:00',
      quietHoursEnd: '07:00',
    );
    final legacy = legacyNotificationPrefsPayload(prefs.toMap());

    expect(legacy.containsKey('class_reminder_lead_min'), isFalse);
    expect(legacy.containsKey('notif_onboarded_at'), isFalse);
    // 원래 있던 컬럼은 그대로 저장돼야 한다.
    expect(legacy['push_enabled'], isTrue);
    expect(legacy['morning_digest_enabled'], isTrue);
    expect(legacy['class_reminder_enabled'], isTrue);
    expect(legacy['quiet_hours_start'], '22:00');
    expect(legacy['quiet_hours_end'], '07:00');
  });

  test('폴백 페이로드는 원본을 건드리지 않는다', () {
    final original = const NotificationPrefs(classReminderLeadMin: 10).toMap();
    legacyNotificationPrefsPayload(original);
    expect(original['class_reminder_lead_min'], 10);
  });
}
