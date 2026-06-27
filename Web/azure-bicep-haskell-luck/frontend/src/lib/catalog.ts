// 체크리스트 카탈로그는 세션 내내 거의 불변이므로 한 번만 로드해 전역에서 공유한다.
// createRoot 로 컴포넌트 밖 싱글톤 resource 를 만들어, 화면 전환마다 재요청하지 않는다.

import { createResource, createRoot } from "solid-js";
import { api } from "./api";

const shared = createRoot(() => {
  const [catalog, { refetch }] = createResource(() => api.catalog.list());
  return { catalog, refetchCatalog: refetch };
});

/** 공유 카탈로그 접근자(미로드 시 undefined). */
export const catalog = shared.catalog;

/** 카탈로그를 다시 불러온다(관리자가 항목을 수정한 뒤 등). */
export const refetchCatalog = shared.refetchCatalog;
