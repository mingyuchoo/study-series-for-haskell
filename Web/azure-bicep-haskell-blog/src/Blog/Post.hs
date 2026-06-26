-- | 글 도메인 타입과 저장소 추상('Blog.User' 와 대칭).
--
-- 저장(insert/update)은 순수 저장 행 'Post' 를, 조회(list/get)는 화면 표시용
-- 읽기 모델 'PostView'(글 + 작성자 이름)를 다룬다. 웹 계층은 구체 구현이 아니라
-- 'PostStore' 핸들에만 의존한다(DB 없이 인메모리 구현 주입 가능).
module Blog.Post
  ( Post (..)
  , PostView (..)
  , NewPost (..)
  , PostStore (..)
  ) where

import Data.Text (Text)
import Data.Time (UTCTime)

-- | 저장된 블로그 글(posts 테이블 한 행). 작성자 표시 이름 같은 표현 관심사는
--   섞지 않는다 — 그건 'PostView' 가 담는다.
data Post = Post
  { postId        :: Int
  , postTitle     :: Text
  , postBody      :: Text
  , postCreatedAt :: UTCTime
  , postAuthorId  :: Int
    -- ^ 작성자(users.id).
  }
  deriving stock (Show, Eq)

-- | 화면 표시용 읽기 모델 — 글 + 작성자 표시 이름(users JOIN 으로 채운다).
--   저장(insert/update)은 'Post' 를, 조회(list/get)는 'PostView' 를 다룬다.
data PostView = PostView
  { pvPost       :: Post
  , pvAuthorName :: Text
  }
  deriving stock (Show, Eq)

-- | 아직 저장되지 않은 새 글 입력값.
data NewPost = NewPost
  { newPostTitle :: Text
  , newPostBody  :: Text
  }
  deriving stock (Show, Eq)

-- | 저장소 연산 모음 (record-of-functions 핸들).
data PostStore = PostStore
  { storeList         :: Int -> Int -> IO [PostView]
    -- ^ 글을 최신순으로 페이지 조회 (limit, offset). 홈 목록이 글 수에 비례해
    --   비대해지지 않도록 항상 한 페이지 분량만 가져온다.
  , storeListByAuthor :: Int -> IO [PostView]
    -- ^ 특정 작성자(users.id)의 글을 최신순으로 조회.
  , storeGet          :: Int -> IO (Maybe PostView)
    -- ^ ID로 글 조회. 없으면 'Nothing'.
  , storeInsert       :: Int -> NewPost -> IO Post
    -- ^ 작성자 id와 내용을 받아 새 글을 저장하고 'Post' 반환.
  , storeUpdate       :: Int -> NewPost -> IO (Maybe Post)
    -- ^ ID로 글 내용을 수정(작성자는 유지). 없으면 'Nothing'.
  , storeDelete       :: Int -> IO Bool
    -- ^ ID로 글 삭제. 실제로 삭제되었으면 'True'.
  }
