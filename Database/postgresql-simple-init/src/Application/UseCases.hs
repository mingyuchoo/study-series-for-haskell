module Application.UseCases
  ( createUserUC
  , deleteUserUC
  , getUserUC
  , initializeDatabase
  , listAllUsers
  , seedSampleData
  , updateUserUC
  ) where

import Domain.Model (User (..))
import Domain.Repository (UserRepository (..))

-- | 스키마 준비: 애플리케이션 계층은 인터페이스에만 의존
initializeDatabase :: (UserRepository m, Applicative m) => m Bool
initializeDatabase = pure True -- 구체 구현은 어댑터/인프라에서 수행

-- | 샘플 데이터 삽입 유스케이스
seedSampleData :: (UserRepository m, Monad m) => m Bool
seedSampleData = do
  _ <- createUser (User 1 "Jacob")
  _ <- updateUser (User 1 "Tomas")
  pure True

-- | 전체 조회 유스케이스
listAllUsers :: (UserRepository m) => m [User]
listAllUsers = listUsers

-- | 생성 유스케이스
createUserUC :: (UserRepository m) => User -> m Bool
createUserUC = createUser

-- | 수정 유스케이스
updateUserUC :: (UserRepository m) => User -> m Bool
updateUserUC = updateUser

-- | 삭제 유스케이스
deleteUserUC :: (UserRepository m) => Int -> m Bool
deleteUserUC = deleteUser

-- | 상세 조회 유스케이스
getUserUC :: (UserRepository m) => Int -> m (Maybe User)
getUserUC = retrieveUser
