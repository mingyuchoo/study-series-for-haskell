// 로컬 타임존 기준 날짜 헬퍼.

export function pad(n: number): string {
  return String(n).padStart(2, "0");
}

/** Date -> "YYYY-MM-DD" (로컬). */
export function fmt(d: Date): string {
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

/** 오늘 날짜 문자열. */
export function todayStr(): string {
  return fmt(new Date());
}

/** Date -> "HH:MM" (로컬). */
export function hhmm(d: Date): string {
  return `${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

/** "YYYY-MM-DD" -> 로컬 Date. */
export function parse(s: string): Date {
  const [y, m, d] = s.split("-").map(Number);
  return new Date(y, m - 1, d);
}

export const WEEKDAYS = ["일", "월", "화", "수", "목", "금", "토"];

export interface MonthCell {
  date: string;
  day: number;
  inMonth: boolean;
}

/**
 * 해당 연/월(0-based month)의 달력 격자를 만든다.
 * 앞뒤 달의 날짜로 6주(42칸)를 채운다.
 */
export function monthGrid(year: number, month: number): MonthCell[] {
  const first = new Date(year, month, 1);
  const start = new Date(year, month, 1 - first.getDay());
  const cells: MonthCell[] = [];
  for (let i = 0; i < 42; i++) {
    const d = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i);
    cells.push({
      date: fmt(d),
      day: d.getDate(),
      inMonth: d.getMonth() === month,
    });
  }
  return cells;
}

export function monthLabel(year: number, month: number): string {
  return `${year}년 ${month + 1}월`;
}
