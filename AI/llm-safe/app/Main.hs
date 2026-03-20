{-# LANGUAGE OverloadedStrings #-}

-- | LLM 비결정성 관리 TUI — brick 기반 터미널 UI.
module Main
    ( main
    ) where

import qualified Brick                      as B
import qualified Brick.BChan                as BChan
import qualified Brick.Widgets.Border       as Border
import qualified Brick.Widgets.Border.Style as BS
import qualified Brick.Widgets.Edit         as Edit

import qualified Configuration.Dotenv       as Dotenv

import           Control.Concurrent         (forkIO)
import           Control.Monad              (void, when)
import           Control.Monad.IO.Class     (liftIO)

import qualified Graphics.Vty               as Vty
import qualified Graphics.Vty.CrossPlatform as VtyCross

import           LlmSafe                    (consensusPipeline, defaultConfig,
                                             populationPipeline)
import           LlmSafe.Types              (LlmConfig (..), LlmError, renderLlmError)

-- ---------------------------------------------------------------------------
-- 타입 정의
-- ---------------------------------------------------------------------------

-- | 위젯 이름
data Name = CityInputField | LogViewport
     deriving (Eq, Ord, Show)

-- | 파이프라인 모드
data PipelineMode = SingleCall | ConsensusCall
     deriving (Eq, Show)

-- | 커스텀 이벤트 (백그라운드 스레드 → TUI)
data AppEvent = LogMsg String -- ^ 파이프라인 로그 메시지
              | Done (Either LlmError String)

-- | 앱 상태
data AppState = AppState { _cityEdit  :: Edit.Editor String Name
                           -- ^ 도시명 입력 에디터
                         , _pipeMode  :: PipelineMode
                           -- ^ 파이프라인 모드
                         , _logs      :: [String]
                           -- ^ 실행 로그 라인 목록
                         , _running   :: Bool
                           -- ^ 파이프라인 실행 중 여부
                         , _llmConfig :: LlmConfig
                           -- ^ Azure OpenAI 설정
                         , _eventChan :: BChan.BChan AppEvent
                           -- ^ 커스텀 이벤트 채널
                         , _focused   :: Name
                           -- ^ 현재 포커스 위젯
                         }

-- ---------------------------------------------------------------------------
-- 초기 상태
-- ---------------------------------------------------------------------------

initialState :: LlmConfig -> BChan.BChan AppEvent -> AppState
initialState cfg ch = AppState
  { _cityEdit  = Edit.editor CityInputField (Just 1) "서울"
  , _pipeMode  = SingleCall
  , _logs      = ["[준비] 도시명을 입력하고 Enter를 누르세요."]
  , _running   = False
  , _llmConfig = cfg
  , _eventChan = ch
  , _focused   = CityInputField
  }

-- ---------------------------------------------------------------------------
-- Brick 앱 정의
-- ---------------------------------------------------------------------------

tuiApp :: B.App AppState AppEvent Name
tuiApp = B.App
  { B.appDraw         = drawUI
  , B.appChooseCursor = B.showFirstCursor
  , B.appHandleEvent  = handleEvent
  , B.appStartEvent   = pure ()
  , B.appAttrMap      = const theAttrMap
  }

-- ---------------------------------------------------------------------------
-- UI 렌더링
-- ---------------------------------------------------------------------------

drawUI :: AppState -> [B.Widget Name]
drawUI st = [ui]
  where
    ui =
      B.withBorderStyle BS.unicodeRounded $
      Border.borderWithLabel
        (B.str "[ LLM 비결정성 관리 — Haskell 타입 안전성 ]") $
      B.vBox
        [ inputSection
        , Border.hBorder
        , logSection
        , Border.hBorder
        , helpBar
        ]

    inputSection =
      B.padAll 1 $
      B.vBox
        [ B.hBox
            [ B.str "파이프라인 : "
            , modeBtn SingleCall    "단일 호출(1회)"
            , B.str "    "
            , modeBtn ConsensusCall ("합의 기반(" <> show (configConsensusCount (_llmConfig st)) <> "회)")
            ]
        , B.str " "
        , B.hBox
            [ B.str "도시명     : "
            , B.hLimit 40 $
                Edit.renderEditor
                  (B.str . unlines)
                  (_focused st == CityInputField)
                  (_cityEdit st)
            ]
        ]

    modeBtn m label =
      let icon = if _pipeMode st == m then "[●] " else "[ ] "
      in B.str (icon <> label)

    logSection =
      B.padLeftRight 1 $
      B.viewport LogViewport B.Vertical $
      B.vBox (map B.str (_logs st))

    helpBar =
      B.padLeftRight 1 $
      B.hBox
        [ if _running st
            then B.withAttr runningAttr (B.str "⟳ 실행 중...")
            else B.withAttr keyAttr     (B.str "Enter:실행")
        , sep
        , B.withAttr keyAttr (B.str "Tab:전환")
        , sep
        , B.withAttr keyAttr (B.str "Space:모드변경")
        , sep
        , B.withAttr keyAttr (B.str "Esc:종료")
        ]

    sep = B.str "  │  "

-- ---------------------------------------------------------------------------
-- 속성 맵
-- ---------------------------------------------------------------------------

runningAttr, keyAttr :: B.AttrName
runningAttr = B.attrName "running"
keyAttr     = B.attrName "key"

theAttrMap :: B.AttrMap
theAttrMap = B.attrMap Vty.defAttr
  [ (runningAttr,          Vty.withForeColor Vty.defAttr Vty.yellow)
  , (keyAttr,              Vty.withForeColor Vty.defAttr Vty.cyan)
  , (Edit.editFocusedAttr, Vty.withStyle     Vty.defAttr Vty.reverseVideo)
  ]

-- ---------------------------------------------------------------------------
-- 이벤트 처리
-- ---------------------------------------------------------------------------

handleEvent :: B.BrickEvent Name AppEvent -> B.EventM Name AppState ()
handleEvent ev = case ev of

  -- 커스텀: 로그 한 줄 추가
  B.AppEvent (LogMsg msg) -> do
    B.modify $ \st -> st { _logs = _logs st ++ [msg] }
    B.vScrollToEnd (B.viewportScroll LogViewport)

  -- 커스텀: 파이프라인 완료
  B.AppEvent (Done result) -> do
    let line = case result of
                 Right s -> "✓ 완료: " <> s
                 Left  e -> "✗ 실패: " <> renderLlmError e
    B.modify $ \st -> st
      { _running = False
      , _logs    = _logs st ++ [line, replicate 50 '─']
      }
    B.vScrollToEnd (B.viewportScroll LogViewport)

  -- Esc: 종료
  B.VtyEvent (Vty.EvKey Vty.KEsc []) -> B.halt

  -- Tab: 포커스 전환 (입력창 ↔ 로그)
  B.VtyEvent (Vty.EvKey (Vty.KChar '\t') []) ->
    B.modify $ \st -> st
      { _focused = if _focused st == CityInputField
                     then LogViewport
                     else CityInputField
      }

  -- Space: 파이프라인 모드 변경 (로그 영역에서만)
  B.VtyEvent (Vty.EvKey (Vty.KChar ' ') []) -> do
    st <- B.get
    when (_focused st == LogViewport) $
      B.modify $ \s -> s
        { _pipeMode = if _pipeMode s == SingleCall
                        then ConsensusCall
                        else SingleCall
        }

  -- Enter: 파이프라인 실행 (입력창 + 미실행 중)
  B.VtyEvent (Vty.EvKey Vty.KEnter []) -> do
    st <- B.get
    when (_focused st == CityInputField && not (_running st)) runPipeline

  -- 방향키: 로그 스크롤 (로그 영역에서만)
  B.VtyEvent (Vty.EvKey Vty.KUp []) -> do
    st <- B.get
    when (_focused st == LogViewport) $
      B.vScrollBy (B.viewportScroll LogViewport) (-3)

  B.VtyEvent (Vty.EvKey Vty.KDown []) -> do
    st <- B.get
    when (_focused st == LogViewport) $
      B.vScrollBy (B.viewportScroll LogViewport) 3

  -- 나머지 키: 입력창에 전달
  _ -> do
    st <- B.get
    when (_focused st == CityInputField) $ do
      newEd <- B.nestEventM' (_cityEdit st) (Edit.handleEditorEvent ev)
      B.modify $ \s -> s { _cityEdit = newEd }

-- ---------------------------------------------------------------------------
-- 파이프라인 실행 (백그라운드 스레드)
-- ---------------------------------------------------------------------------

runPipeline :: B.EventM Name AppState ()
runPipeline = do
  st <- B.get
  let cityName = concat (Edit.getEditContents (_cityEdit st))
      ch       = _eventChan st
      cfg      = _llmConfig st
      mode     = _pipeMode st
      logger   = BChan.writeBChan ch . LogMsg
  B.modify $ \s -> s
    { _running = True
    , _logs    = _logs s ++
        [ replicate 50 '─'
        , "▶ 도시: " <> cityName <> "  모드: " <> showMode cfg mode
        ]
    }
  liftIO $ void $ forkIO $ do
    result <- case mode of
      SingleCall    -> populationPipeline cfg logger cityName
      ConsensusCall -> consensusPipeline  cfg logger (configConsensusCount cfg) cityName
    BChan.writeBChan ch (Done result)

showMode :: LlmConfig -> PipelineMode -> String
showMode _   SingleCall    = "단일 호출(1회)"
showMode cfg ConsensusCall = "합의 기반(" <> show (configConsensusCount cfg) <> "회)"

-- ---------------------------------------------------------------------------
-- 진입점
-- ---------------------------------------------------------------------------

main :: IO ()
main = do
  Dotenv.loadFile Dotenv.defaultConfig
  config <- defaultConfig
  ch <- BChan.newBChan 20
  let buildVty = VtyCross.mkVty Vty.defaultConfig
  initialVty <- buildVty
  void $ B.customMain initialVty buildVty (Just ch) tuiApp (initialState config ch)
