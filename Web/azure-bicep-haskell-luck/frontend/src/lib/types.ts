// 백엔드와 주고받는 DTO 계약 타입 (Haskell Luck.Types 와 수동 동기화).

export interface UserDTO {
  id: string;
  email: string;
  displayName: string;
  bio: string;
  timezone: string;
  createdAt: string;
}

export interface AuthResp {
  token: string;
  user: UserDTO;
}

export interface CatalogItem {
  key: string;
  label: string;
}

export interface RecordDTO {
  date: string;
  completed: string[];
  note: string | null;
  total: number;
}
