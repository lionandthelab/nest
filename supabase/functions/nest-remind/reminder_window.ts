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
