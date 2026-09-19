module Todo.Web.ConfigSpec (spec) where

import Test.Hspec
import Todo.Web.Config

spec :: Spec
spec = describe "web 설정 해석" $ do
  it "값이 없으면 기본값을 사용한다" $
    resolveConfig Nothing Nothing
      `shouldBe` WebConfig{webPort = defaultPort, webDatabasePath = defaultDatabasePath}

  it "지정한 포트와 경로를 사용한다" $
    resolveConfig (Just "/tmp/other.db") (Just "9000")
      `shouldBe` WebConfig{webPort = 9000, webDatabasePath = "/tmp/other.db"}

  it "포트가 숫자가 아니면 기본 포트로 되돌린다" $
    webPort (resolveConfig Nothing (Just "팔공팔일")) `shouldBe` defaultPort

  it "빈 포트 문자열도 기본 포트로 되돌린다" $
    webPort (resolveConfig Nothing (Just "")) `shouldBe` defaultPort

  it "데이터베이스 경로는 cli 및 api와 같은 기본값을 쓴다" $
    defaultDatabasePath `shouldBe` "todo.db"
