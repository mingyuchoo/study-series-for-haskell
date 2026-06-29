// 백엔드와 주고받는 DTO 계약 타입 (Haskell Luck.Types 와 수동 동기화).

export interface UserDTO {
  id: string;
  email: string;
  displayName: string;
  bio: string;
  timezone: string;
  isAdmin: boolean;
  createdAt: string;
  themeKey: string;
}

export interface AuthResp {
  token: string;
  user: UserDTO;
}

/** 공개 카탈로그 항목 (활성 항목만 내려오므로 active를 담지 않는다). */
export interface CatalogItem {
  key: string;
  label: string;
}

/** 관리자용 카탈로그 항목 (비활성 항목도 다루므로 active 포함). */
export interface AdminCatalogItem {
  key: string;
  label: string;
  active: boolean;
}

export interface RecordDTO {
  date: string;
  completed: string[];
  note: string | null;
  total: number;
}
