{-# LANGUAGE OverloadedStrings #-}

import qualified Data.Vector as Vec
import Brick.Main (renderWidget)
import qualified Data.Text as T
import qualified Data.Text.Lazy as TL
import Hfm.Tui.UI (drawUI)
import Hfm.Application.Status
import Hfm.Application.Ports (FileError (..))
import Hfm.Tui.I18n (translate, renderStatus)
import Graphics.Vty.PictureToSpans (displayOpsForPic)
import Graphics.Vty.Span (SpanOp (..))
import Brick (attrName, attrMapLookup)
import qualified Graphics.Vty as V
import Hfm.Tui.Theme (themeAttributes, effectiveTheme)
import Hfm.Domain.Theme (themes, themeName)
import Hfm.Domain.Selection (selection, selectAt)
import Hfm.Domain.Entry
import Test.Hspec
import Hfm.Application.State hiding (initialState, toggleLanguage)
import qualified Hfm.Application.State as State
import Hfm.Tui.Layout
import qualified SyntaxHighlightSpec

main :: IO ()
main = hspec spec

initialState :: FilePath -> [Entry] -> FilePath -> [Entry] -> AppConfig -> (Int, Int) -> AppState
initialState left entries right other config size = prepareLayout (State.initialState left entries right other config size)

toggleLanguage :: AppState -> AppState
toggleLanguage = prepareLayout . State.toggleLanguage

viewerRows :: AppState -> [T.Text]
viewerRows st =
  let size = stTerminalSize st
      picture = renderWidget Nothing (drawUI st) size
      spanText (TextSpan _ _ _ value) = TL.toStrict value
      spanText (Skip count) = T.replicate count " "
      spanText (RowEnd count) = T.replicate count " "
  in map (T.concat . map spanText . Vec.toList) (Vec.toList (displayOpsForPic picture size))

spec :: Spec
spec = do
  describe "한국어/영어 메뉴 전환" $ do
    it "한국어로 시작하고 두 번 전환하면 원래 언어로 돌아온다" $ do
      let st = initialState "/tmp" [] "/tmp" [] defaultConfig (160, 24)
      stLanguage st `shouldBe` Korean
      stLanguage (toggleLanguage st) `shouldBe` English
      stLanguage (toggleLanguage (toggleLanguage st)) `shouldBe` Korean

    it "모든 모드의 메뉴와 상태를 번역하고 사용자 입력은 유지한다" $ do
      let entries = [Entry "한글.txt" RegularFile 1]
          base = initialState "/tmp" entries "/tmp" entries defaultConfig (160, 24)
          cases = [(Browse, "File manager"), (Search, "Search: "),
                   (Prompt Copy "한글/대상", "Copy to: "), (Prompt Move "한글/대상", "Move/rename to: "),
                   (Prompt Mkdir "한글/대상", "New folder: "), (ConfirmDelete, "Confirm delete: "),
                   (ViewFile "/tmp/한글.txt" "한글 내용" 0, "View: ")]
      mapM_ (\(mode, label) -> do
        let st = base { stMode = mode, stInputCursor = 2, stPendingCtrlX = True }
            changed = toggleLanguage st
            rendered = T.unlines (viewerRows changed)
        rendered `shouldSatisfy` T.isInfixOf label
        rendered `shouldSatisfy` T.isInfixOf "F2 English"
        rendered `shouldSatisfy` T.isInfixOf "Quit"
        stMode changed `shouldBe` mode
        stInputCursor changed `shouldBe` 2
        stPendingCtrlX changed `shouldBe` True
        selectedEntry changed `shouldBe` selectedEntry st
        panelSearch (activePanel changed) `shouldBe` panelSearch (activePanel st)
        T.unlines (viewerRows (toggleLanguage changed)) `shouldBe` T.unlines (viewerRows st)) cases
      T.unlines (viewerRows (toggleLanguage base)) `shouldSatisfy` T.isInfixOf "Ready"
      T.unlines (viewerRows (toggleLanguage (base { stMode = ViewFile "/tmp/한글.txt" "한글 내용" 0 })))
        `shouldSatisfy` T.isInfixOf "한글 내용"

    it "상태 오류를 번역하고 임의 경로와 시스템 오류는 유지한다" $ do
      translate English "오류: 파일 접근 권한이 없습니다" `shouldBe` "Error: Permission denied"
      translate English "오류: user error (대상 경로가 이미 존재합니다)"
        `shouldBe` "Error: user error (Destination already exists)"
      translate English "/tmp/한글.txt" `shouldBe` "/tmp/한글.txt"
      translate English "오류: /tmp/한글.txt: system error" `shouldBe` "Error: /tmp/한글.txt: system error"

    it "언어 전환 후에도 좁은 파일 보기의 마지막 줄과 종료 안내를 분리한다" $ do
      let content = T.unlines ["LINE-" <> T.pack (show n) | n <- [0 :: Int .. 59]]
      mapM_ (\size -> do
        let st = (initialState "/tmp" [] "/tmp" [] defaultConfig size)
                   { stMode = ViewFile "/tmp/test.txt" content 999 }
        mapM_ (\changed -> do
          let rows = viewerRows changed
              footerStart = snd size - length (viewerHelpLines changed)
          map T.strip (drop footerStart rows) `shouldBe` viewerHelpLines changed
          rows !! (footerStart - 2) `shouldSatisfy` T.isInfixOf "LINE-59")
          [toggleLanguage st, toggleLanguage (toggleLanguage st)]) [(40, 12), (60, 10), (80, 24)]

  describe "Semantic status presentation" $ do
    it "renders outcomes and typed errors in the selected language" $ do
      renderStatus Korean Copied `shouldBe` "복사했습니다"
      renderStatus English Copied `shouldBe` "Copied"
      renderStatus Korean (Failed Missing) `shouldBe` "오류: 파일이 존재하지 않습니다"
      renderStatus English (Failed PermissionDenied) `shouldBe` "Error: Permission denied"

    it "never translates a path that happens to equal a status label" $ do
      renderStatus English (CurrentDirectory "준비") `shouldBe` "준비"
      renderStatus English (CurrentDirectory "/tmp/한글.txt") `shouldBe` "/tmp/한글.txt"

  describe "파일 보기 하단 렌더링" $ do
    it "좁은 터미널에서도 하단 안내의 종료 키까지 표시한다" $ do
      let st = (initialState "/tmp" [] "/tmp" [] defaultConfig (40, 12))
                 { stMode = ViewFile "/tmp/test.txt" "first\nlast" 0 }
      T.unlines (viewerRows st) `shouldSatisfy` T.isInfixOf "종료"

    it "화면 크기와 접두 명령에 관계없이 안내 문구와 마지막 줄을 분리한다" $ do
      let content = T.unlines ["LINE-" <> T.pack (show n) | n <- [0 :: Int .. 59]]
      mapM_ (\(size, prefixPending) -> do
        let st = (initialState "/tmp" [] "/tmp" [] defaultConfig size)
                   { stMode = ViewFile "/tmp/test.txt" content 999, stPendingCtrlX = prefixPending }
            rows = viewerRows st
            footerStart = snd size - length (viewerHelpLines st)
        map T.strip (drop footerStart rows) `shouldBe` viewerHelpLines st
        rows !! (footerStart - 2) `shouldSatisfy` T.isInfixOf "LINE-59"
        rows !! (footerStart - 1) `shouldSatisfy` T.isPrefixOf "└")
        [(size, prefixPending) | size <- [(40, 12), (60, 10), (80, 24), (120, 30)], prefixPending <- [False, True]]
    it "빈 줄도 한 행을 차지해 파일 줄 위치를 보존한다" $ do
      let st = (initialState "/tmp" [] "/tmp" [] defaultConfig (40, 12))
                 { stMode = ViewFile "/tmp/test.txt" "first\n\nthird" 0 }
          rows = viewerRows st
      rows !! 2 `shouldSatisfy` T.isInfixOf "first"
      T.strip (rows !! 3) `shouldBe` "│                                      │"
      rows !! 4 `shouldSatisfy` T.isInfixOf "third"
    it "크기를 늘려도 마지막 페이지 위쪽이 비지 않고 끝까지 보인다" $ do
      let content = T.unlines ["LINE-" <> T.pack (show n) | n <- [0 :: Int .. 59]]
          small = initialState "/tmp" [] "/tmp" [] defaultConfig (40, 12)
          oldOffset = clampViewerOffset small content 999
          large = prepareLayout (small { stTerminalSize = (80, 24), stMode = ViewFile "/tmp/test.txt" content oldOffset })
          rows = viewerRows large
      rows !! 2 `shouldSatisfy` T.isInfixOf "LINE-40"
      rows !! 21 `shouldSatisfy` T.isInfixOf "LINE-59"
      clampViewerOffset large content 999 `shouldBe` 40
    it "내용 영역이 없는 작은 높이에서도 음수 크기로 렌더링하지 않는다" $ do
      let st = (initialState "/tmp" [] "/tmp" [] defaultConfig (40, 4))
                 { stMode = ViewFile "/tmp/test.txt" "last" 0 }
      viewerContentHeight st `shouldBe` 0
      length (viewerRows st) `shouldBe` 4

  describe "Viewer tab rendering" $ do
    it "renders Makefile indentation and blank tab lines with the active theme background" $ do
      let content = "target:\n\tstack build\n\t\n가\t값\nx\t\tz"
      mapM_ (\(theme, preview) -> do
        let st = (initialState "/tmp" [] "/tmp" [] defaultConfig (80, 40))
                   { stTheme = theme, stMode = ViewFile "/tmp/Makefile" content 0
                   , stThemePicker = if preview then Just (selectAt (fromEnum theme) (selection themes)) else Nothing }
            attributes = themeAttributes (effectiveTheme st)
            size = stTerminalSize st
            ops = displayOpsForPic (renderWidget (Just attributes) (drawUI st) size) size
            body = concatMap Vec.toList (take 5 (drop 2 (Vec.toList ops)))
            background = V.attrBackColor (attrMapLookup (attrName "default") attributes)
            text (TextSpan _ _ _ value) = TL.toStrict value
            text (Skip count) = T.replicate count " "
            text (RowEnd count) = T.replicate count " "
            rows = map (T.concat . map text . Vec.toList) (Vec.toList ops)
        rows !! 3 `shouldSatisfy` T.isPrefixOf "│        stack build"
        rows !! 5 `shouldSatisfy` T.isPrefixOf "│가      값"
        rows !! 6 `shouldSatisfy` T.isPrefixOf "│x               z"
        mapM_ (\op -> case op of
          TextSpan attribute _ _ value -> do
            V.attrBackColor attribute `shouldBe` background
            TL.any (== '\t') value `shouldBe` False
          _ -> expectationFailure ("Unpainted viewer cells: " ++ show op)) body) [(theme, preview) | theme <- themes, preview <- [False, True]]

  SyntaxHighlightSpec.spec

  describe "VS Code theme rendering" $ do
    it "uses each theme's editor colors across the full screen" $ do
      let rgbColor :: Int -> Int -> Int -> V.Color
          rgbColor = V.rgbColor
          backgrounds = [rgbColor 255 255 255, rgbColor 30 30 30, rgbColor 39 40 34,
                         rgbColor 253 246 227, rgbColor 0 43 54, rgbColor 0 36 81]
      mapM_ (\(theme, background) -> do
        let attributes = themeAttributes theme
            normal = attrMapLookup (attrName "default") attributes
            selected = attrMapLookup (attrName "selected") attributes
        V.attrBackColor normal `shouldBe` V.SetTo background
        V.attrBackColor selected `shouldNotBe` V.attrBackColor normal
        V.attrForeColor selected `shouldNotBe` V.attrBackColor selected) (zip themes backgrounds)

    it "renders every choice, current theme, and bilingual controls" $ do
      mapM_ (\language -> do
        let st = (initialState "/tmp" [] "/tmp" [] defaultConfig (80, 24))
                   { stLanguage = language, stThemePicker = Just (selectAt 2 (selection themes)) }
            rendered = T.unlines (viewerRows st)
        mapM_ (\theme -> rendered `shouldSatisfy` T.isInfixOf (themeName theme)) themes
        rendered `shouldSatisfy` T.isInfixOf (if language == Korean then "테마 선택" else "Select theme")
        effectiveTheme st `shouldBe` Monokai
        effectiveTheme (st { stThemePicker = Nothing }) `shouldBe` Dark) [Korean, English]

    it "renders a scrollable picker safely on small terminals" $ do
      mapM_ (\size -> do
        let st = (initialState "/tmp" [] "/tmp" [] defaultConfig size)
                   { stThemePicker = Just (selectAt 5 (selection themes)) }
        length (viewerRows st) `shouldBe` snd size) [(40, 12), (30, 8), (20, 4)]
