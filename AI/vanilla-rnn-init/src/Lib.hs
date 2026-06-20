{-# LANGUAGE BangPatterns #-}

module Lib
  ( trainExample
  ) where

import System.Random

-- | 벡터 타입 (리스트로 표현)
type Vector = [Double]

-- | 행렬 타입 (리스트의 리스트로 표현)
type Matrix = [[Double]]

-- | RNN 파라미터
data RNNParams = RNNParams
  { wxh :: Matrix
    -- 입력-은닉층 가중치
  , whh :: Matrix
    -- 은닉층-은닉층 가중치 (recurrent)
  , why :: Matrix
    -- 은닉층-출력층 가중치
  , bh  :: Vector
    -- 은닉층 편향
  , by  :: Vector
    -- 출력층 편향
  }
  deriving (Show)

-- | RNN 상태
data RNNState = RNNState
  { hiddenState :: Vector
  }
  deriving (Show)

-- ============= 행렬/벡터 연산 =============

-- | 행렬-벡터 곱셈
matVecMul :: Matrix -> Vector -> Vector
matVecMul m v = map (sum . zipWith (*) v) m

-- | 벡터 덧셈
vecAdd :: Vector -> Vector -> Vector
vecAdd = zipWith (+)

-- | 벡터 뺄셈
vecSub :: Vector -> Vector -> Vector
vecSub = zipWith (-)

-- | 벡터 스칼라 곱셈
vecScale :: Double -> Vector -> Vector
vecScale s = map (* s)

-- | 외적 (outer product)
outerProduct :: Vector -> Vector -> Matrix
outerProduct v1 v2 = [[x * y | y <- v2] | x <- v1]

-- | 전치 행렬
transpose :: Matrix -> Matrix
transpose [] = []
transpose ([] : _) = []
transpose m =
  map (\row -> case row of (x : _) -> x; [] -> error "transpose: empty row") m
    : transpose (map (\row -> case row of (_ : xs) -> xs; [] -> []) m)

-- | 행렬 덧셈
matAdd :: Matrix -> Matrix -> Matrix
matAdd = zipWith (zipWith (+))

-- ============= 활성화 함수 =============

-- | Tanh 활성화 함수
tanhActivation :: Vector -> Vector
tanhActivation = map tanh

-- | Tanh 미분
tanhDerivative :: Vector -> Vector
tanhDerivative xs = map (\x -> 1 - x * x) xs

-- | Softmax 함성화 함수
softmax :: Vector -> Vector
softmax xs = map (/ sumExp) expXs
  where
    maxX = maximum xs
    expXs = map (\x -> exp (x - maxX)) xs
    sumExp = sum expXs

-- ============= RNN 초기화 =============

-- | 랜덤 행렬 생성
randomMatrix :: Int -> Int -> StdGen -> (Matrix, StdGen)
randomMatrix rows cols gen =
  let (values, gen') = randomList (rows * cols) gen
      scale = 0.01
   in (chunksOf cols (map (* scale) values), gen')

-- | 랜덤 벡터 생성
randomVector :: Int -> StdGen -> (Vector, StdGen)
randomVector n gen =
  let (values, gen') = randomList n gen
   in (values, gen')

-- | 랜덤 리스트 생성
randomList :: Int -> StdGen -> ([Double], StdGen)
randomList 0 gen = ([], gen)
randomList n gen =
  let (x, gen') = randomR (-1.0, 1.0) gen
      (xs, gen'') = randomList (n - 1) gen'
   in (x : xs, gen'')

-- | 리스트를 청크로 분할
chunksOf :: Int -> [a] -> [[a]]
chunksOf _ [] = []
chunksOf n xs = take n xs : chunksOf n (drop n xs)

-- | RNN 초기화
initRNN :: Int -> Int -> Int -> StdGen -> RNNParams
initRNN inputSize hiddenSize outputSize gen =
  let (wxh', gen1) = randomMatrix hiddenSize inputSize gen
      (whh', gen2) = randomMatrix hiddenSize hiddenSize gen1
      (why', gen3) = randomMatrix outputSize hiddenSize gen2
      (bh', gen4) = randomVector hiddenSize gen3
      (by', _) = randomVector outputSize gen4
   in RNNParams wxh' whh' why' bh' by'

-- | 초기 은닉 상태
initHiddenState :: Int -> RNNState
initHiddenState hiddenSize = RNNState (replicate hiddenSize 0.0)

-- ============= RNN Forward Pass =============

-- | RNN 한 스텝 forward
rnnStep :: RNNParams -> RNNState -> Vector -> (Vector, RNNState, Vector)
rnnStep params state input =
  let h_prev = hiddenState state
      -- h_t = tanh(W_xh * x_t + W_hh * h_{t-1} + b_h)
      h_raw =
        (wxh params `matVecMul` input)
          `vecAdd` (whh params `matVecMul` h_prev)
          `vecAdd` bh params
      h_t = tanhActivation h_raw
      -- y_t = W_hy * h_t + b_y
      y_raw = (why params `matVecMul` h_t) `vecAdd` by params
      y_t = softmax y_raw
      newState = RNNState h_t
   in (y_t, newState, h_t)

-- | 시퀀스에 대한 RNN forward
rnnForward :: RNNParams -> RNNState -> [Vector] -> ([Vector], [RNNState])
rnnForward params initState inputs = go initState inputs [] []
  where
    go _ [] outputs states = (reverse outputs, reverse states)
    go state (x : xs) outputs states =
      let (y, newState, _) = rnnStep params state x
       in go newState xs (y : outputs) (newState : states)

-- ============= RNN Backward Pass (BPTT) =============

-- | 그래디언트 구조
data RNNGradients = RNNGradients
  { dwxh :: Matrix
  , dwhh :: Matrix
  , dwhy :: Matrix
  , dbh  :: Vector
  , dby  :: Vector
  }
  deriving (Show)

-- | 그래디언트 초기화 (0으로)
zeroGradients :: Int -> Int -> Int -> RNNGradients
zeroGradients inputSize hiddenSize outputSize =
  RNNGradients
    { dwxh = replicate hiddenSize (replicate inputSize 0.0),
      dwhh = replicate hiddenSize (replicate hiddenSize 0.0),
      dwhy = replicate outputSize (replicate hiddenSize 0.0),
      dbh = replicate hiddenSize 0.0,
      dby = replicate outputSize 0.0
    }

-- | 그래디언트 덧셈
addGradients :: RNNGradients -> RNNGradients -> RNNGradients
addGradients g1 g2 =
  RNNGradients
    { dwxh = matAdd (dwxh g1) (dwxh g2),
      dwhh = matAdd (dwhh g1) (dwhh g2),
      dwhy = matAdd (dwhy g1) (dwhy g2),
      dbh = vecAdd (dbh g1) (dbh g2),
      dby = vecAdd (dby g1) (dby g2)
    }

-- | 파라미터 업데이트
updateParams :: Double -> RNNParams -> RNNGradients -> RNNParams
updateParams lr params grads =
  RNNParams
    { wxh = matAdd (wxh params) (scaleMatrix (-lr) (dwxh grads)),
      whh = matAdd (whh params) (scaleMatrix (-lr) (dwhh grads)),
      why = matAdd (why params) (scaleMatrix (-lr) (dwhy grads)),
      bh = vecAdd (bh params) (vecScale (-lr) (dbh grads)),
      by = vecAdd (by params) (vecScale (-lr) (dby grads))
    }
  where
    scaleMatrix s = map (map (* s))

-- | 손실 함수 (Cross-Entropy)
crossEntropyLoss :: Vector -> Vector -> Double
crossEntropyLoss target output =
  negate $ sum $ zipWith (\t o -> t * log (o + 1e-8)) target output

-- ============= 학습 예제 =============

-- | 간단한 시퀀스 예측 예제
trainExample :: IO ()
trainExample = do
  gen <- getStdGen
  let inputSize = 3
      hiddenSize = 5
      outputSize = 3
      learningRate = 0.1
      epochs = 500

  -- RNN 초기화
  let params = initRNN inputSize hiddenSize outputSize gen

  -- 예제 데이터: 간단한 시퀀스
  let inputs = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]
      targets = [[0, 1, 0], [0, 0, 1], [1, 0, 0]]

  -- 학습
  putStrLn "RNN 학습 시작..."
  let trainedParams = trainLoop params inputs targets learningRate epochs

  -- 테스트
  putStrLn "\n학습된 모델 테스트:"
  let (outputs, _) = rnnForward trainedParams (initHiddenState hiddenSize) inputs
  mapM_
    ( \(i, o, t) -> do
        putStrLn $ "입력: " ++ show i
        putStrLn $ "예측: " ++ show o
        putStrLn $ "정답: " ++ show t
        putStrLn ""
    )
    (zip3 inputs outputs targets)

-- | 학습 루프
trainLoop :: RNNParams -> [Vector] -> [Vector] -> Double -> Int -> RNNParams
trainLoop params _ _ _ 0 = params
trainLoop params inputs targets lr epochs =
  let (outputs, states) = rnnForward params (initHiddenState (length (bh params))) inputs
      loss = sum $ zipWith crossEntropyLoss targets outputs
      -- 간단한 그래디언트 업데이트 (실제로는 BPTT 필요)
      grads = computeSimpleGradients params inputs targets outputs states
      newParams = updateParams lr params grads
   in if epochs `mod` 10 == 0
        then
          trace
            ("Epoch " ++ show (100 - epochs + 1) ++ ", Loss: " ++ show loss)
            (trainLoop newParams inputs targets lr (epochs - 1))
        else trainLoop newParams inputs targets lr (epochs - 1)

-- | 단순화된 그래디언트 계산
computeSimpleGradients :: RNNParams -> [Vector] -> [Vector] -> [Vector] -> [RNNState] -> RNNGradients
computeSimpleGradients params inputs targets outputs states =
  let inputSize = case inputs of (x : _) -> length x; [] -> 0
      hiddenSize = length (bh params)
      outputSize = length (by params)
      zeroGrads = zeroGradients inputSize hiddenSize outputSize
      -- 역순으로 처리하며 그래디언트 누적
      gradsWithHidden = reverse $ go (reverse inputs) (reverse targets) (reverse outputs) (reverse states) (replicate hiddenSize 0.0) []
   in foldr addGradients zeroGrads gradsWithHidden
  where
    go [] [] [] [] _ acc = acc
    go (inp : inps) (tgt : tgts) (out : outs) (st : sts) dh_next acc =
      let grad = computeStepGradients params inp tgt out (hiddenState st) dh_next
          -- 다음 타임스텝으로 전파할 은닉층 그래디언트
          dh_next' = matVecMul (transpose (whh params)) (dbh grad)
       in go inps tgts outs sts dh_next' (grad : acc)
    go _ _ _ _ _ acc = acc

-- | 각 스텝의 그래디언트 계산
computeStepGradients :: RNNParams -> Vector -> Vector -> Vector -> Vector -> Vector -> RNNGradients
computeStepGradients params input target output h_t dh_next =
  let -- 출력층 그래디언트
      dy = vecSub output target
      -- 은닉층으로 역전파
      dh_raw = vecAdd (matVecMul (transpose (why params)) dy) dh_next
      -- tanh 미분 적용
      dh = zipWith (*) dh_raw (tanhDerivative h_t)
   in RNNGradients
        { dwxh = outerProduct dh input,
          dwhh = outerProduct dh h_t,
          dwhy = outerProduct dy h_t,
          dbh = dh,
          dby = dy
        }

-- | trace 함수 (디버깅용)
trace :: String -> a -> a
trace msg x = seq (length msg) x
