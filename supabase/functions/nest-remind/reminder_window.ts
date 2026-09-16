// 수업 전 알림 발송 판정 (순수 함수).
//
// index.ts 에서 떼어낸 이유: 이 판정이 조용히 틀리면 알림이 안 가거나 엉뚱한
// 때 간다. 둘 다 사용자가 신고하지 않고 그냥 알림을 꺼 버리는 종류의 고장이라
// 눈으로는 못 잡는다. 테스트로 못박아 둔다.

/** 사용자가 고를 수 있는 리드타임(분). DB check 제약과 같은 목록이다. */
export const LEAD_CHOICES = [10, 20, 30, 60];

export const DEFAULT_LEAD = 30;

/**
 * 한 번 도는 발송 잡이 훑는 폭(분).
 *
 * cron 주기(pg_cron 5분, GitHub Actions 10분)보다 넉넉해야 한 번 밀렸을 때
 * 알림이 통째로 빠지지 않는다. 창이 겹쳐 두 번 걸려도 claimSend 의 유니크
 * 인덱스가 중복 발송을 막는다.
 */
export const SEND_WINDOW = 10;

export function normalizeLead(value: unknown): number {
  const lead = typeof value === "number" ? value : Number(value);
  return LEAD_CHOICES.includes(lead) ? lead : DEFAULT_LEAD;
}

/**
 * 지금 이 사람에게 이 수업 알림을 보낼 때인지.
 *
 * [minutesUntilStart] 수업 시작까지 남은 분. 이미 시작했으면 0 이하.
 * [leadMin] 이 사람이 고른 "몇 분 전".
 *
 * 고른 시각보다 **이르게는 보내지 않는다**. "30분 전"이라고 해 놓고 35분 전에
 * 보내면 문구가 거짓말이 된다. 대신 잡이 밀렸을 때를 대비해 한 창만큼 늦게까지는
 * 허용한다.
 */
export function shouldSendClassReminder(
  minutesUntilStart: number,
  leadMin: number,
): boolean {
  if (minutesUntilStart <= 0) return false;
  if (minutesUntilStart > leadMin) return false;
  return minutesUntilStart > leadMin - SEND_WINDOW;
}

/** 조용한 시간 판정에 필요한 만큼만. */
export interface QuietHours {
  quiet_hours_start: string | null;
  quiet_hours_end: string | null;
}

function minutesFromTime(value: string): number {
  const [h, m] = value.split(":");
  return (Number(h) || 0) * 60 + (Number(m) || 0);
}

/**
 * 지금이 이 사람의 조용한 시간인지.
 *
 * 기본값이 21:00~07:00 이라 자정을 넘는 구간이 보통이다. 시작과 끝이 같으면
 * "구간 없음"으로 본다 — 하루 종일 막히는 쪽보다 안 막히는 쪽이 덜 위험하다.
 */
export function inQuietHours(prefs: QuietHours, minutes: number): boolean {
  if (!prefs.quiet_hours_start || !prefs.quiet_hours_end) return false;
  const start = minutesFromTime(prefs.quiet_hours_start);
  const end = minutesFromTime(prefs.quiet_hours_end);
  if (start === end) return false;
  if (start < end) return minutes >= start && minutes < end;
  return minutes >= start || minutes < end;
}

// ── 아침 오늘 일정 ──────────────────────────────────────────────────────

/**
 * 아침 알림으로 고를 수 있는 시각(자정부터 분).
 * 06:30 / 07:00 / 07:30 / 08:00. DB check 제약과 같은 목록이다.
 *
 * 자유 입력을 안 받는 이유는 리드타임과 같다. 발송 잡이 30분 격자로 돌기
 * 때문에, 격자에 없는 시각은 제 때 걸리지 않는다.
 */
export const MORNING_CHOICES = [
  6 * 60 + 30,
  7 * 60,
  7 * 60 + 30,
  8 * 60,
];

/** 지금 동작과 같은 07:30. 이미 쓰고 있는 사람은 아무것도 바뀌지 않는다. */
export const DEFAULT_MORNING_MIN = 7 * 60 + 30;

/**
 * 아침 잡이 한 번에 훑는 폭(분).
 *
 * cron 주기(30분)보다 커야 한 번 걸렀을 때 다음 회차가 건진다. 그렇지 않으면
 * 그 날 아침을 통째로 놓친다. 창이 겹쳐 두 번 걸려도 claimSend 가 막는다.
 */
export const MORNING_WINDOW = 35;

export function normalizeMorningMin(value: unknown): number {
  const at = typeof value === "number" ? value : Number(value);
  return MORNING_CHOICES.includes(at) ? at : DEFAULT_MORNING_MIN;
}

/**
 * 지금 이 사람에게 아침 알림을 보낼 때인지.
 *
 * [nowMinutes] 서울 기준 지금 시각(자정부터 분).
 * [digestMinutes] 이 사람이 고른 시각.
 *
 * 고른 시각보다 이르게는 보내지 않는다. 대신 잡이 밀렸을 때를 위해 한 창만큼
 * 늦게까지 허용한다 — 아침 알림은 조금 늦더라도 오는 편이 안 오는 것보다 낫다.
 */
export function shouldSendMorningDigest(
  nowMinutes: number,
  digestMinutes: number,
): boolean {
  const delta = nowMinutes - digestMinutes;
  return delta >= 0 && delta < MORNING_WINDOW;
}
