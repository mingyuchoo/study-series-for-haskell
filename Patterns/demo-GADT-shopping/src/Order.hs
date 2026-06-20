{-# LANGUAGE DataKinds          #-}
{-# LANGUAGE DeriveGeneric      #-}
{-# LANGUAGE GADTs              #-}
{-# LANGUAGE KindSignatures     #-}
{-# LANGUAGE OverloadedStrings  #-}
{-# LANGUAGE StandaloneDeriving #-}

module Order
  where

import Data.Text (Text)
import GHC.Generics (Generic)

-- 상태 타입
data Cart
data Paid
data Shipped
data Delivered

-- 오류 타입
data OrderError = PaymentFailed Text
                | ShippingFailed Text
  deriving (Show, Generic)

-- 이벤트 타입
data OrderLog = LogCreated
              | LogPaid
              | LogShipped
              | LogDelivered
              | LogPaymentFailed Text
              | LogShippingFailed Text
  deriving (Show, Generic)

-- GADT 상태 머신
data Order s where New :: Order Cart
                   Pay :: Order Cart -> Order Paid
                   Ship :: Order Paid -> Order Shipped
                   Deliver :: Order Shipped -> Order Delivered

instance Show (Order s) where
  show New         = "Order: Cart (장바구니 상태)"
  show (Pay _)     = "Order: Paid (결제 완료)"
  show (Ship _)    = "Order: Shipped (배송 중)"
  show (Deliver _) = "Order: Delivered (배송 완료)"

-- 비즈니스 규칙
shouldPaymentFail :: Bool
shouldPaymentFail = False

shouldShippingFail :: Bool
shouldShippingFail = False

-- 상태 전이를 로그와 함께 처리
processStepNew :: Order Cart -> [OrderLog] -> Either OrderError (Order Paid, [OrderLog])
processStepNew New logs =
  if shouldPaymentFail
    then
      Left (PaymentFailed "카드 승인 실패")
    else
      let paid = Pay New
       in Right (paid, logs ++ [LogPaid])

processStepPaid
  :: Order Paid -> [OrderLog] -> Either OrderError (Order Shipped, [OrderLog])
processStepPaid o@(Pay _) logs =
  if shouldShippingFail
    then
      Left (ShippingFailed "주소지 배송 불가")
    else
      let shipped = Ship o
       in Right (shipped, logs ++ [LogShipped])

processStepShipped
  :: Order Shipped -> [OrderLog] -> Either OrderError (Order Delivered, [OrderLog])
processStepShipped o@(Ship _) logs =
  let delivered = Deliver o
   in Right (delivered, logs ++ [LogDelivered])

runOrder :: Either OrderError (Order Delivered, [OrderLog])
runOrder = do
  let logs0 = [LogCreated]
  (paid, logs1) <- processStepNew New logs0
  (shipped, logs2) <- processStepPaid paid logs1
  (delivered, logs3) <- processStepShipped shipped logs2
  return (delivered, logs3)
