{-# LANGUAGE OverloadedStrings #-}

-- | UI rendering functions (Pure)
module UI.Draw
    ( charWidth
    , drawUI
    , statusToAttrName
    , statusToDisplayText
    , statusToIcon
    , stringWidth
    , truncateToWidth
    , truncateWithEllipsis
    ) where

import           Brick                (Widget, attrName, hBox, padAll,
                                       padTopBottom, str, vBox, vLimit,
                                       withAttr)
import qualified Brick
import           Brick.Widgets.Border (borderWithLabel, hBorder)
import           Brick.Widgets.Center (center, hCenter)
import qualified Brick.Widgets.Edit   as E
import           Brick.Widgets.List   (listElementsL, listSelected, renderList)

import qualified Config

import qualified Data.Vector          as Vec

import           Flow                 ((<|))

import qualified I18n

import           Lens.Micro           ((^.))

import           UI.Types

-- | 상태 문자열을 리스트 아이콘으로 변환 (Pure)
statusToIcon :: String -> String
statusToIcon "registered"  = "[R] "
statusToIcon "in_progress" = "[P] "
statusToIcon "cancelled"   = "[X] "
statusToIcon "completed"   = "[✓] "
statusToIcon _             = "[ ] "

-- | 상태 문자열을 속성 이름으로 변환 (Pure)
statusToAttrName :: String -> String
statusToAttrName "registered"  = "registered"
statusToAttrName "in_progress" = "in_progress"
statusToAttrName "cancelled"   = "cancelled"
statusToAttrName "completed"   = "completed"
statusToAttrName _             = "normal"

-- | 상태 문자열을 i18n 표시 텍스트로 변환 (Pure)
statusToDisplayText :: I18n.StatusMessages -> String -> String
statusToDisplayText msgs "registered"  = I18n.registered msgs
statusToDisplayText msgs "in_progress" = I18n.in_progress msgs
statusToDisplayText msgs "cancelled"   = I18n.cancelled msgs
statusToDisplayText msgs "completed"   = I18n.completed msgs
statusToDisplayText _    _             = "Unknown"

drawUI :: AppState -> [Widget Name]
drawUI s =
    [ vBox
        [ drawHeader s
        , hBorder
        , drawTodoList s
        , hBorder
        , drawDetailView s
        , hBorder
        , drawErrorBar s
        , drawHelp s
        ]
    ]

drawHeader :: AppState -> Widget Name
drawHeader s =
    withAttr (attrName "header")
        $ hCenter
        $ padTopBottom 1
        $ str
        $ I18n.header (I18n.ui (s ^. i18nMessages))

drawTodoList :: AppState -> Widget Name
drawTodoList s =
    let msgs = s ^. i18nMessages
        uiMsgs = I18n.ui msgs
    in borderWithLabel (str $ I18n.todos_title uiMsgs)
        $ padAll 1
        $ vLimit 20
        $ if null (s ^. todoList . listElementsL)
            then center $ str $ I18n.no_todos uiMsgs
            else renderList (drawTodo msgs) True (s ^. todoList)

drawTodo :: I18n.I18nMessages -> Bool -> Todo -> Widget Name
drawTodo msgs selected todo = withAttr selectAttr todoWidget
  where
    listMsgs = I18n.list msgs
    status = todo ^. todoStatus
    statusIcon = str $ statusToIcon status
    todoAttr = attrName $ statusToAttrName status
    selectAttr = if selected then attrName "selected" else todoAttr
    showField _ Nothing  = ""
    showField lbl (Just v) =
        I18n.field_separator listMsgs <> lbl <> ": " <> v
    mainInfo = concat
        [ I18n.field_action listMsgs <> ": " <> todo ^. todoAction
        , showField (I18n.field_subject listMsgs) (todo ^. todoSubject)
        , showField (I18n.field_indirect listMsgs) (todo ^. todoIndirectObject)
        , showField (I18n.field_direct listMsgs) (todo ^. todoDirectObject)
        ]
    fieldMsgs = I18n.fields msgs
    statusChangedText = maybe ""
        (\t -> I18n.status_changed_label fieldMsgs
            <> ": " <> t <> I18n.field_separator listMsgs)
        (todo ^. todoStatusChangedAt)
    timestampText =
        statusChangedText
            <> I18n.created_prefix listMsgs
            <> todo ^. todoCreatedAt
    timestampWidth = stringWidth timestampText + 2
    todoWidget = Brick.Widget Brick.Greedy Brick.Fixed <| do
        ctx <- Brick.getContext
        let totalWidth = Brick.availWidth ctx
            availableForMain = totalWidth - 4 - timestampWidth
            truncatedMain = truncateWithEllipsis availableForMain mainInfo
            paddingWidth = max 0 (availableForMain - stringWidth truncatedMain)
        Brick.render $ hBox
            [ statusIcon
            , str truncatedMain
            , str (replicate paddingWidth ' ')
            , withAttr (attrName "timestamp") $ str timestampText
            ]

-- | CJK/전각 문자의 표시 너비를 계산 (Pure)
charWidth :: Char -> Int
charWidth c
    | c >= '\x1100' && c <= '\x11FF' = 2
    | c >= '\x3000' && c <= '\x303F' = 2
    | c >= '\x3130' && c <= '\x318F' = 2
    | c >= '\xAC00' && c <= '\xD7AF' = 2
    | c >= '\xFF00' && c <= '\xFFEF' = 2
    | c >= '\x4E00' && c <= '\x9FFF' = 2
    | otherwise = 1

stringWidth :: String -> Int
stringWidth = sum . map charWidth

truncateWithEllipsis :: Int -> String -> String
truncateWithEllipsis maxW text
    | stringWidth text <= maxW = text
    | maxW <= 3 = "..."
    | otherwise = truncateToWidth (maxW - 3) text <> "..."

truncateToWidth :: Int -> String -> String
truncateToWidth maxW = go 0
  where
    go _ [] = []
    go w (c:cs)
        | w + charWidth c > maxW = []
        | otherwise = c : go (w + charWidth c) cs

drawDetailView :: AppState -> Widget Name
drawDetailView s =
    let msgs = s ^. i18nMessages
        uiMsgs = I18n.ui msgs
    in case s ^. mode of
        ViewMode   -> drawViewModeDetail s msgs uiMsgs
        EditMode _ -> drawEditModeDetail s msgs uiMsgs
        InputMode  -> drawInputModeDetail s msgs uiMsgs

drawViewModeDetail :: AppState -> I18n.I18nMessages -> I18n.UIMessages -> Widget Name
drawViewModeDetail s msgs uiMsgs =
    case listSelected (s ^. todoList) of
        Nothing -> emptyDetailView uiMsgs (I18n.no_selection uiMsgs)
        Just idx -> case (s ^. todoList . listElementsL) Vec.!? idx of
            Nothing   -> emptyDetailView uiMsgs (I18n.no_selection uiMsgs)
            Just todo -> drawTodoDetail msgs uiMsgs todo

drawEditModeDetail :: AppState -> I18n.I18nMessages -> I18n.UIMessages -> Widget Name
drawEditModeDetail s msgs uiMsgs =
    case s ^. editingIndex of
        Nothing -> emptyDetailView uiMsgs (I18n.not_found uiMsgs)
        Just idx -> case (s ^. todoList . listElementsL) Vec.!? idx of
            Nothing   -> emptyDetailView uiMsgs (I18n.not_found uiMsgs)
            Just todo -> drawTodoDetailWithEditors s msgs todo
                            (I18n.detail_edit_title uiMsgs)

drawInputModeDetail :: AppState -> I18n.I18nMessages -> I18n.UIMessages -> Widget Name
drawInputModeDetail s msgs uiMsgs =
    let fieldMsgs = I18n.fields msgs
        statusMsgs = I18n.status msgs
    in borderWithLabel (str $ I18n.detail_add_title uiMsgs)
        $ padAll 1
        $ vLimit 8
        $ vBox
            [ hBox [ withAttr (attrName "detailLabel")
                        $ str (I18n.id_label fieldMsgs <> ": ")
                   , withAttr (attrName "timestamp")
                        $ str $ I18n.auto_generated_label fieldMsgs
                   ]
            , hBox [ withAttr (attrName "detailLabel")
                        $ str (I18n.status_label fieldMsgs <> ": ")
                   , str $ I18n.in_progress statusMsgs
                   ]
            , renderEditField s fieldMsgs
                (I18n.action_required_label fieldMsgs)
                (s ^. actionEditor) FocusAction
            , renderEditField s fieldMsgs
                (I18n.subject_label fieldMsgs)
                (s ^. subjectEditor) FocusSubject
            , renderEditField s fieldMsgs
                (I18n.indirect_object_label fieldMsgs)
                (s ^. indirectObjectEditor) FocusIndirectObject
            , renderEditField s fieldMsgs
                (I18n.direct_object_label fieldMsgs)
                (s ^. directObjectEditor) FocusDirectObject
            , hBox [ withAttr (attrName "detailLabel")
                        $ str (I18n.created_at_label fieldMsgs <> ": ")
                   , withAttr (attrName "timestamp")
                        $ str $ I18n.auto_generated_label fieldMsgs
                   ]
            , str ""
            ]

emptyDetailView :: I18n.UIMessages -> String -> Widget Name
emptyDetailView uiMsgs msg =
    borderWithLabel (str $ I18n.detail_title uiMsgs)
        $ padAll 1
        $ center
        $ str msg

drawTodoDetail :: I18n.I18nMessages -> I18n.UIMessages -> Todo -> Widget Name
drawTodoDetail msgs uiMsgs todo =
    let fieldMsgs = I18n.fields msgs
        statusMsgs = I18n.status msgs
        status = todo ^. todoStatus
        statusText = statusToDisplayText statusMsgs status
        statusAttr = attrName $ statusToAttrName status
        showDetailField _ Nothing = str ""
        showDetailField lbl (Just val) =
            hBox [ withAttr (attrName "detailLabel") $ str (lbl <> ": ")
                 , str val
                 ]
        statusChangedInfo = case todo ^. todoStatusChangedAt of
            Just t -> hBox
                [ withAttr (attrName "detailLabel")
                    $ str (I18n.status_changed_label fieldMsgs <> ": ")
                , withAttr (attrName "timestamp") $ str t
                ]
            Nothing -> str ""
    in borderWithLabel (str $ I18n.detail_title uiMsgs)
        $ padAll 1
        $ vLimit 8
        $ vBox
            [ hBox [ withAttr (attrName "detailLabel")
                        $ str (I18n.id_label fieldMsgs <> ": ")
                   , str (show (todo ^. todoId))
                   ]
            , hBox [ withAttr (attrName "detailLabel")
                        $ str (I18n.status_label fieldMsgs <> ": ")
                   , withAttr statusAttr $ str statusText
                   ]
            , hBox [ withAttr (attrName "detailLabel")
                        $ str (I18n.action_label fieldMsgs <> ": ")
                   , str (todo ^. todoAction)
                   ]
            , showDetailField (I18n.subject_label fieldMsgs)
                (todo ^. todoSubject)
            , showDetailField (I18n.indirect_object_label fieldMsgs)
                (todo ^. todoIndirectObject)
            , showDetailField (I18n.direct_object_label fieldMsgs)
                (todo ^. todoDirectObject)
            , hBox [ withAttr (attrName "detailLabel")
                        $ str (I18n.created_at_label fieldMsgs <> ": ")
                   , withAttr (attrName "timestamp")
                        $ str (todo ^. todoCreatedAt)
                   ]
            , statusChangedInfo
            ]

drawTodoDetailWithEditors :: AppState -> I18n.I18nMessages -> Todo -> String -> Widget Name
drawTodoDetailWithEditors s msgs todo title =
    let fieldMsgs = I18n.fields msgs
        statusMsgs = I18n.status msgs
        status = todo ^. todoStatus
        statusText = statusToDisplayText statusMsgs status
        statusAttr = attrName $ statusToAttrName status
        statusChangedInfo = case todo ^. todoStatusChangedAt of
            Just t -> hBox
                [ withAttr (attrName "detailLabel")
                    $ str (I18n.status_changed_label fieldMsgs <> ": ")
                , withAttr (attrName "timestamp") $ str t
                ]
            Nothing -> str ""
    in borderWithLabel (str title)
        $ padAll 1
        $ vLimit 8
        $ vBox
            [ hBox [ withAttr (attrName "detailLabel")
                        $ str (I18n.id_label fieldMsgs <> ": ")
                   , str (show (todo ^. todoId))
                   ]
            , hBox [ withAttr (attrName "detailLabel")
                        $ str (I18n.status_label fieldMsgs <> ": ")
                   , withAttr statusAttr $ str statusText
                   ]
            , renderEditField s fieldMsgs
                (I18n.action_required_label fieldMsgs)
                (s ^. actionEditor) FocusAction
            , renderEditField s fieldMsgs
                (I18n.subject_label fieldMsgs)
                (s ^. subjectEditor) FocusSubject
            , renderEditField s fieldMsgs
                (I18n.indirect_object_label fieldMsgs)
                (s ^. indirectObjectEditor) FocusIndirectObject
            , renderEditField s fieldMsgs
                (I18n.direct_object_label fieldMsgs)
                (s ^. directObjectEditor) FocusDirectObject
            , hBox [ withAttr (attrName "detailLabel")
                        $ str (I18n.created_at_label fieldMsgs <> ": ")
                   , withAttr (attrName "timestamp")
                        $ str (todo ^. todoCreatedAt)
                   ]
            , statusChangedInfo
            ]

renderEditField :: AppState -> I18n.FieldLabels -> String
               -> E.Editor String Name -> FocusedField -> Widget Name
renderEditField s _ fieldLabel editor fieldType =
    let isFocused = s ^. focusedField == fieldType
        fieldAttr = if isFocused
            then attrName "focusedField"
            else attrName "detailLabel"
    in hBox [ withAttr fieldAttr $ str (fieldLabel <> ": ")
            , E.renderEditor (str . unlines) isFocused editor
            ]

-- | 에러 메시지 표시 바 (Pure)
drawErrorBar :: AppState -> Widget Name
drawErrorBar s = case s ^. errorMessage of
    Nothing  -> str ""
    Just msg -> withAttr (attrName "error") $ hCenter $ str msg

drawHelp :: AppState -> Widget Name
drawHelp s =
    let msgs = s ^. i18nMessages
        helpMsgs = I18n.help msgs
    in padAll 1 $ case s ^. mode of
        InputMode  -> str $ I18n.input_mode helpMsgs
        EditMode _ -> str $ I18n.edit_mode helpMsgs
        ViewMode   -> drawViewModeHelp s helpMsgs

drawViewModeHelp :: AppState -> I18n.HelpMessages -> Widget Name
drawViewModeHelp s helpMsgs =
    let kb = keyBindings s
        quitKeys   = Config.getFirstKey (Config.quit kb) "q"
        addKeys    = Config.getFirstKey (Config.add_todo kb) "a"
        editKeys   = Config.getFirstKey (Config.edit_todo kb) "e"
        toggleKeys = Config.getFirstKey (Config.toggle_complete kb) "t"
        deleteKeys = Config.getFirstKey (Config.delete_todo kb) "d"
        upKeys     = Config.getFirstKey (Config.navigate_up kb) "k"
        downKeys   = Config.getFirstKey (Config.navigate_down kb) "j"
    in vBox
        [ str $ addKeys <> ": " <> I18n.add helpMsgs
            <> " | " <> editKeys <> ": " <> I18n.edit helpMsgs
            <> " | " <> toggleKeys <> ": " <> I18n.toggle helpMsgs
            <> " | " <> deleteKeys <> ": " <> I18n.delete helpMsgs
            <> " | " <> upKeys <> "/" <> downKeys
            <> ": " <> I18n.navigate helpMsgs
            <> " | " <> quitKeys <> ": " <> I18n.quit helpMsgs
        ]
