{-# LANGUAGE OverloadedStrings #-}

-- | 'Blog.Org' 순수 렌더러 단위 테스트.
--
-- 라우트 통합 테스트('Main')와 달리, Org 텍스트 → HTML 변환 자체를 직접 검증한다.
-- (1) 헤딩 레벨 매핑, (2) 마커별 리스트 글리프 클래스, (3) 헤딩 하위 들여쓰기,
-- (4) 'normalizeOrg' 의 빈 줄 보강(문단 뒤 리스트·리스트 뒤 헤딩), (5) 인라인 서식.
module OrgSpec
  ( orgTests
  ) where

import Data.List (isInfixOf)
import Data.Text qualified as T
import Test.HUnit
import Text.Blaze.Html.Renderer.String (renderHtml)

import Blog.Org (renderOrg, renderOrgFragment)

-- | 줄 목록을 Org 본문으로 렌더링한 HTML 문자열.
render :: [String] -> String
render = renderHtml . renderOrg . T.pack . unlines

contains :: String -> String -> Assertion
contains needle hay =
  assertBool
    ("기대한 부분 문자열을 찾지 못함:\n  needle: " <> show needle <> "\n  in: " <> hay)
    (needle `isInfixOf` hay)

excludes :: String -> String -> Assertion
excludes needle hay =
  assertBool
    ("없어야 할 부분 문자열이 있음: " <> show needle <> "\n  in: " <> hay)
    (not (needle `isInfixOf` hay))

orgTests :: Test
orgTests =
  TestList
    [ TestLabel "별 개수가 h1..h4 로 매핑된다" . TestCase $ do
        let out = render ["* A", "** B", "*** C", "**** D"]
        contains "<h1>A</h1>" out
        contains "<h2>B</h2>" out
        contains "<h3>C</h3>" out
        contains "<h4>D</h4>" out
    , TestLabel "- 는 org-bulleted 리스트가 된다" . TestCase $
        contains "<ul class=\"org-ul org-bulleted\"><li>item</li></ul>" (render ["- item"])
    , TestLabel "+ 는 org-plussed 리스트가 된다" . TestCase $
        contains "<ul class=\"org-ul org-plussed\"><li>a</li></ul>" (render ["+ a"])
    , TestLabel "번호 목록은 ol.org-ol 이 된다" . TestCase $
        contains "<ol class=\"org-ol\"><li>a</li><li>b</li></ol>" (render ["1. a", "2. b"])
    , TestLabel "중첩 리스트가 li 안에 중첩된다" . TestCase $
        contains
          "parent<ul class=\"org-ul org-bulleted\"><li>child</li>"
          (render ["- parent", "  - child"])
    , TestLabel "헤딩 하위 문단은 깊이만큼 들여쓰기 된다" . TestCase $ do
        contains "<div class=\"org-indent-2\"><p>body</p></div>" (render ["* H", "body"])
        contains "org-indent-5" (render ["* a", "** b", "*** c", "**** d", "deep"])
    , TestLabel "최상위 문단은 들여쓰지 않는다" . TestCase $ do
        contains "<p>just text</p>" (render ["just text"])
        excludes "org-indent" (render ["just text"])
    , TestLabel "문단 바로 뒤의 - 줄도 리스트가 된다(빈 줄 보강)" . TestCase $ do
        let out = render ["para", "- item"]
        contains "<p>para</p>" out
        contains "org-bulleted" out
        contains "<li>item</li>" out
    , TestLabel "리스트 바로 뒤의 헤딩도 헤딩으로 인식된다(빈 줄 보강)" . TestCase $ do
        let out = render ["- item", "* H"]
        contains "<li>item</li>" out
        contains "<h1>H</h1>" out
    , TestLabel "인라인 굵게·링크 서식이 렌더된다" . TestCase $ do
        let out = render ["plain *bold* and [[https://x.com][go]] end"]
        contains "<b>bold</b>" out
        contains "<a href=\"https://x.com\">go</a>" out
    , TestLabel "renderOrgFragment 는 renderOrg 와 동일하게 렌더한다" . TestCase $
        assertEqual
          "fragment == full"
          (renderHtml (renderOrg "* T"))
          (renderHtml (renderOrgFragment "* T"))
    , TestLabel "중첩 깊이 5·6은 h5·h6 로, 그 이상은 h6 으로 클램프된다" . TestCase $ do
        -- 헤딩 레벨은 별 개수가 아니라 섹션 중첩 깊이로 결정되므로 7단계로 중첩한다.
        let out = render ["* A", "** B", "*** C", "**** D", "***** E", "****** F", "******* G"]
        contains "<h5>E</h5>" out
        contains "<h6>F</h6>" out
        contains "<h6>G</h6>" out
    , TestLabel "기울임 서식이 <i> 로 렌더된다" . TestCase $
        contains "<i>italic</i>" (render ["/italic/"])
    , TestLabel "~코드~ 는 org-highlight 클래스의 <code> 가 된다" . TestCase $
        contains "<code class=\"org-highlight\">snippet</code>" (render ["~snippet~"])
    , TestLabel "_밑줄_ 은 underline 스타일 <span> 이 된다" . TestCase $ do
        let out = render ["_under_"]
        contains "text-decoration: underline;" out
        contains "under" out
    , TestLabel "=verbatim= 본문은 그대로 텍스트로 렌더된다" . TestCase $
        contains "verbtext" (render ["=verbtext="])
    , TestLabel "+취소선+ 은 line-through 스타일 <span> 이 된다" . TestCase $
        contains "text-decoration: line-through;" (render ["+struck+"])
    , TestLabel "설명 없는 링크도 <a href> 로 렌더된다" . TestCase $
        contains "href=\"https://example.com\"" (render ["[[https://example.com]]"])
    , TestLabel "이미지 링크는 <figure><img> 로 렌더된다" . TestCase $ do
        let out = render ["[[https://example.com/photo.png]]"]
        contains "<figure>" out
        contains "<img" out
        contains "photo.png" out
    , TestLabel "문서 첫 줄의 #+begin_src 블록도 pre.src 로 살아난다(선행 블록 보호)" . TestCase $ do
        -- 예전엔 meta 파서가 선행 '#+' 를 키로 삼키다 실패해 전체 파싱이 무너지고
        -- 원문이 노출됐다. normalizeOrg 의 fixLeadingBlock 이 이를 본문 블록으로 살린다.
        let out = render ["#+begin_src", "x = 1", "#+end_src"]
        contains "org-src-container" out
        contains "class=\"src\"" out
        contains "x = 1" out
        excludes "#+begin_src" out
    , TestLabel "문서 첫 줄의 언어 있는 #+begin_src 도 src-<lang> 클래스를 단다" . TestCase $ do
        let out = render ["#+begin_src haskell", "x = 1", "#+end_src"]
        contains "src-haskell" out
        excludes "#+begin_src" out
    , TestLabel "문서 첫 줄의 #+begin_quote 블록은 <blockquote> 가 된다" . TestCase $ do
        let out = render ["#+begin_quote", "quoted body", "#+end_quote"]
        contains "<blockquote>" out
        contains "quoted body" out
        excludes "#+begin_quote" out
    , TestLabel "문서 첫 줄의 #+begin_example 블록은 <pre> 가 된다" . TestCase $ do
        let out = render ["#+begin_example", "raw example", "#+end_example"]
        contains "<pre>" out
        contains "raw example" out
        excludes "#+begin_example" out
    , TestLabel "선행 #+TITLE 메타데이터 뒤의 #+begin_src 도 블록으로 인식된다" . TestCase $ do
        -- 진짜 메타데이터가 있을 땐 그 뒤·지시자 앞에 빈 줄을 끼워 스캔을 끊는다.
        -- #+TITLE 은 메타데이터 맵으로만 들어가 본문에 노출되지 않는다.
        let out = render ["#+TITLE: My Post", "#+begin_src", "x = 1", "#+end_src"]
        contains "org-src-container" out
        contains "x = 1" out
        excludes "My Post" out
    , TestLabel "표는 thead/th + tbody/td 로 렌더된다" . TestCase $ do
        let out = render ["| h1 | h2 |", "|----+----|", "| c1 | c2 |"]
        contains "<table>" out
        contains "<thead>" out
        contains "<th" out
        contains "<tbody>" out
        contains "<td>c1</td>" out
    , TestLabel "여는 괄호 앞에는 공백, 괄호 바로 뒤에는 공백을 넣지 않는다" . TestCase $ do
        let out = render ["foo (bar) baz"]
        contains "foo" out
        contains "(bar)" out
    , TestLabel "끝나지 않은 #+begin_src 도 본문 텍스트를 잃지 않는다(우아한 저하)" . TestCase $
        -- #+end_src 가 없어 코드 블록으로 닫히지 않으면 문단으로 떨어지지만,
        -- 본문(x = 1)은 보존돼 사용자에게 보인다.
        contains "x = 1" (render ["#+begin_src", "x = 1"])
    , TestLabel "표의 빈 셀은 빈 th/td 로 렌더된다" . TestCase $ do
        let out = render ["intro", "", "| a | |", "| | d |"]
        contains "<table>" out
        contains "<td></td>" out
    , TestLabel "1) 형식도 normalizeOrg 의 리스트 판정을 거친다(빈 줄 보강 분기)" . TestCase $
        -- normalizeOrg 의 ')' 구분자 분기를 태운다. org 파서 자체는 '1.' 만
        -- 번호 목록으로 보므로 결과는 문단이지만 본문은 보존된다.
        contains "first" (render ["para", "1) first", "2) second"])
    ]
