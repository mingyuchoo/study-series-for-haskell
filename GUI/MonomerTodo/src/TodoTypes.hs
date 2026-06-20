{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TemplateHaskell     #-}

module TodoTypes
  where

import Control.Lens.TH

import Data.Default
import Data.Text (Text)

import Monomer

import TextShow

-- 데이터 모델 정의 (상태)

-- | 할일의 카테고리 타입 (집, 일, 운동)
data TodoType = Home | Work | Sports
  deriving (Enum, Eq, Show)

-- | TodoType을 텍스트로 변환하는 인스턴스
instance TextShow TodoType where
  showt Home   = "Home"
  showt Work   = "Work"
  showt Sports = "Sports"

-- | 할일의 완료 상태 (대기중, 완료)
data TodoStatus = Pending | Done
  deriving (Enum, Eq, Show)

-- | TodoStatus를 텍스트로 변환하는 인스턴스
instance TextShow TodoStatus where
  showt Pending = "Pending"
  showt Done    = "Done"

-- | 할일 항목 데이터 타입
data Todo = Todo
  { _todoId      :: Millisecond
  , _todoType    :: TodoType
  , _status      :: TodoStatus
  , _description :: Text
  }
  deriving (Eq, Show)

-- | Todo의 기본값 인스턴스
instance Default Todo where
  def =
    Todo
      { _todoId = 0
      , _todoType = Home
      , _status = Pending
      , _description = ""
      }

-- | 현재 진행중인 액션 상태
data TodoAction = TodoNone
                | TodoAdding
                | TodoEditing Int
                | TodoConfirmingDelete Int Todo
  deriving (Eq, Show)

-- | 애플리케이션의 전체 상태 모델
data TodoModel = TodoModel
  { _todos      :: [Todo]
  , _activeTodo :: Todo
  , _action     :: TodoAction
  }
  deriving (Eq, Show)

-- | 애플리케이션 이벤트 타입
data TodoEvt = TodoInit
             | TodoNew
             | TodoAdd
             | TodoEdit Int Todo
             | TodoSave Int
             | TodoConfirmDelete Int Todo
             | TodoCancelDelete
             | TodoDeleteBegin Int Todo
             | TodoDelete Int Todo
             | TodoShowEdit
             | TodoHideEdit
             | TodoHideEditDone
             | TodoCancel
             | TodosLoaded [Todo]
  deriving (Eq, Show)

makeLenses 'TodoModel
makeLenses 'Todo

-- | 모든 TodoType 값의 리스트
todoTypes :: [TodoType]
todoTypes = enumFrom (toEnum 0)

-- | 모든 TodoStatus 값의 리스트
todoStatuses :: [TodoStatus]
todoStatuses = enumFrom (toEnum 0)
