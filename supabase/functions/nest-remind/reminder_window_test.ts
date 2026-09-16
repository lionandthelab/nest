// 수업 전 알림 발송 판정.
//
// 이 판정이 틀리면 알림이 조용히 안 가거나 엉뚱한 때 간다. 둘 다 사용자가
// 신고하지 않고 그냥 알림을 꺼 버리는 종류의 고장이라, 눈으로는 못 잡는다.
//
// 실행: deno test supabase/functions/nest-remind/reminder_window_test.ts

import { assertEquals } from "jsr:@std/assert@1";
import {
  DEFAULT_LEAD,
  LEAD_CHOICES,
  normalizeLead,
  DEFAULT_MORNING_MIN,
  inQuietHours,
  MORNING_CHOICES,
  MORNING_WINDOW,
  normalizeMorningMin,
  shouldSendMorningDigest,
  SEND_WINDOW,
  shouldSendClassReminder,
} from "./reminder_window.ts";

Deno.test("고른 리드타임에 딱 맞으면 보낸다", () => {
  for (const lead of LEAD_CHOICES) {
    assertEquals(shouldSendClassReminder(lead, lead), true, `lead=${lead}`);
  }
});

Deno.test("리드타임보다 이르면 아직 안 보낸다", () => {
  // 30분 전으로 골랐는데 35분 전에 보내면 "30분 전"이 거짓말이 된다.
  assertEquals(shouldSendClassReminder(35, 30), false);
  assertEquals(shouldSendClassReminder(31, 30), false);
});

Deno.test("한 발송 창 안이면 늦게 돌아도 보낸다", () => {
  // cron 이 밀려도 창 안이면 건진다. 중복은 claimSend 가 막는다.
  assertEquals(shouldSendClassReminder(30 - SEND_WINDOW + 1, 30), true);
});

Deno.test("발송 창을 지나면 보내지 않는다", () => {
  // 너무 늦게 보내면 "30분 전" 알림이 수업 직전에 와서 쓸모가 없다.
  assertEquals(shouldSendClassReminder(30 - SEND_WINDOW, 30), false);
  assertEquals(shouldSendClassReminder(5, 30), false);
});

Deno.test("이미 시작한 수업은 보내지 않는다", () => {
  assertEquals(shouldSendClassReminder(0, 30), false);
  assertEquals(shouldSendClassReminder(-5, 30), false);
});

Deno.test("10분을 골라도 창이 겹쳐 빠지지 않는다", () => {
  // 가장 짧은 리드타임은 창 아래가 0 밑으로 내려간다. 그래도 0 초과면 보낸다.
  assertEquals(shouldSendClassReminder(10, 10), true);
  assertEquals(shouldSendClassReminder(1, 10), true);
  assertEquals(shouldSendClassReminder(0, 10), false);
});

Deno.test("서로 다른 리드타임이 같은 수업에서 각자 제 때 걸린다", () => {
  // 09:00 수업. 08:00(60분 전)에는 60분 선택자만, 08:30 에는 30분 선택자만.
  assertEquals(shouldSendClassReminder(60, 60), true);
  assertEquals(shouldSendClassReminder(60, 30), false);
  assertEquals(shouldSendClassReminder(30, 30), true);
  assertEquals(shouldSendClassReminder(30, 60), false);
});

Deno.test("아침 알림: 고른 시각에 딱 맞으면 보낸다", () => {
  for (const at of MORNING_CHOICES) {
    assertEquals(shouldSendMorningDigest(at, at), true, `at=${at}`);
  }
});

Deno.test("아침 알림: 고른 시각보다 이르면 보내지 않는다", () => {
  const seven = 7 * 60;
  assertEquals(shouldSendMorningDigest(seven - 1, seven), false);
  assertEquals(shouldSendMorningDigest(6 * 60, seven), false);
});

Deno.test("아침 알림: 잡이 한 번 밀려도 다음 회차가 건진다", () => {
  // cron 은 30분마다 돈다. 한 번 걸렀을 때 다음 회차(+30분)가 창 안에 들어와야
  // 그 날 아침을 통째로 놓치지 않는다. 중복은 claimSend 가 막는다.
  const seven = 7 * 60;
  assertEquals(shouldSendMorningDigest(seven + 30, seven), true);
});

Deno.test("아침 알림: 창을 지나면 보내지 않는다", () => {
  // 오후에 "오늘 수업 3개"가 오면 안 된다.
  const seven = 7 * 60;
  assertEquals(shouldSendMorningDigest(seven + MORNING_WINDOW, seven), false);
  assertEquals(shouldSendMorningDigest(12 * 60, seven), false);
});

Deno.test("아침 알림: 서로 다른 시각을 고른 사람이 각자 제 때 받는다", () => {
  const sixThirty = 6 * 60 + 30;
  const eight = 8 * 60;
  assertEquals(shouldSendMorningDigest(sixThirty, sixThirty), true);
  assertEquals(shouldSendMorningDigest(sixThirty, eight), false);
  assertEquals(shouldSendMorningDigest(eight, eight), true);
});

Deno.test("normalizeMorningMin 은 허용 목록 밖 값을 기본값으로 되돌린다", () => {
  assertEquals(normalizeMorningMin(999), DEFAULT_MORNING_MIN);
  assertEquals(normalizeMorningMin(null), DEFAULT_MORNING_MIN);
  assertEquals(normalizeMorningMin("420"), 420);
  // 기본값은 지금 동작(07:30)과 같아야 한다.
  assertEquals(DEFAULT_MORNING_MIN, 7 * 60 + 30);
});

Deno.test("조용한 시간: 자정을 넘는 구간도 판정한다", () => {
  // 21:00~07:00 처럼 날짜를 넘기는 구간이 기본값이다.
  const night = { quiet_hours_start: "21:00", quiet_hours_end: "07:00" };
  assertEquals(inQuietHours(night, 22 * 60), true); // 22:00
  assertEquals(inQuietHours(night, 3 * 60), true); // 03:00
  assertEquals(inQuietHours(night, 12 * 60), false); // 12:00
  assertEquals(inQuietHours(night, 7 * 60), false); // 07:00 정각은 깨어난다
});

Deno.test("조용한 시간: 같은 날 안의 구간도 판정한다", () => {
  const nap = { quiet_hours_start: "13:00", quiet_hours_end: "15:00" };
  assertEquals(inQuietHours(nap, 14 * 60), true);
  assertEquals(inQuietHours(nap, 12 * 60), false);
  assertEquals(inQuietHours(nap, 15 * 60), false);
});

Deno.test("조용한 시간이 없으면 언제든 보낸다", () => {
  assertEquals(
    inQuietHours({ quiet_hours_start: null, quiet_hours_end: null }, 3 * 60),
    false,
  );
  // 시작과 끝이 같으면 "구간 없음"으로 본다.
  assertEquals(
    inQuietHours({ quiet_hours_start: "21:00", quiet_hours_end: "21:00" }, 21 * 60),
    false,
  );
});

Deno.test("normalizeLead 는 허용 목록 밖 값을 기본값으로 되돌린다", () => {
  assertEquals(normalizeLead(45), DEFAULT_LEAD);
  assertEquals(normalizeLead(null), DEFAULT_LEAD);
  assertEquals(normalizeLead("20"), 20);
  assertEquals(normalizeLead(60), 60);
});
