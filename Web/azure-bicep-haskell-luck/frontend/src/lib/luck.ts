// 행운 체크리스트 도메인 계산 (순수). 뷰 컴포넌트에서 분리해 재사용·테스트 가능하게 한다.

/** 완료 개수/전체 → 달성률 퍼센트(0~100, 반올림). */
export function completionPct(completedCount: number, total: number): number {
  return total === 0 ? 0 : Math.round((completedCount / total) * 100);
}

/** 완료 개수/전체 → 달성 비율(0~1). */
export function completionRatio(completedCount: number, total: number): number {
  return total === 0 ? 0 : completedCount / total;
}

/** 달력 히트맵 최대 단계. */
export const HEAT_LEVEL_MAX = 4;

/** 달성 비율(0~1) → 히트맵 단계(0~4). 임계값을 한곳에서 관리한다. */
export function ratioToLevel(ratio: number): number {
  if (ratio <= 0) return 0;
  if (ratio >= 1) return 4;
  if (ratio >= 0.75) return 3;
  if (ratio >= 0.5) return 2;
  return 1;
}

/** 달성률(%)이 완료(100%) 상태인지. */
export function isComplete(pct: number): boolean {
  return pct >= 100;
}
