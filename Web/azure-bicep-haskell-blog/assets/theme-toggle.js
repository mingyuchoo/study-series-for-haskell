(function () {
  var root = document.documentElement;
  var btn = document.getElementById('theme-toggle');
  if (!btn) return;

  // data-auth="1" 이면 로그인 상태 — 토글을 계정에도 저장한다.
  var authed = btn.getAttribute('data-auth') === '1';

  var SUN = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M2 12h2M20 12h2M5 5l1.4 1.4M17.6 17.6L19 19M19 5l-1.4 1.4M6.4 17.6L5 19"/></svg>';
  var MOON = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M21 12.8A9 9 0 1 1 11.2 3 7 7 0 0 0 21 12.8z"/></svg>';

  // 현재 테마의 단일 출처는 <html data-theme> (로그인 사용자는 서버가 계정 값으로
  // 설정, 비로그인은 theme-init 이 localStorage 로 설정).
  function current() {
    return root.getAttribute('data-theme') === 'dark' ? 'dark' : 'light';
  }

  function render(t) {
    var dark = t === 'dark';
    btn.innerHTML = (dark ? MOON : SUN) + '<span>' + (dark ? '다크' : '라이트') + '</span>';
    btn.setAttribute('aria-label', dark ? '다크 테마 — 클릭하면 라이트로' : '라이트 테마 — 클릭하면 다크로');
  }

  // 로그인 사용자는 선택을 계정에 저장(기기 간 동기화). 실패는 조용히 무시.
  function persist(t) {
    if (!authed) return;
    try {
      fetch('/profile/theme', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: 'theme=' + encodeURIComponent(t),
      });
    } catch (e) {}
  }

  function apply(t) {
    root.setAttribute('data-theme', t);
    try { localStorage.setItem('theme', t); } catch (e) {}
    render(t);
    persist(t);
  }

  btn.addEventListener('click', function () {
    apply(current() === 'dark' ? 'light' : 'dark');
  });

  render(current());
})();
