module Sound.Tidal.MIDI.Control where

import qualified Sound.Tidal.Stream as S

type RangeMapFunc = (Int, Int) -> Float -> Int

data Param = CC { name :: String, midi :: Int, range :: (Int, Int), vdefault :: Double, scalef :: RangeMapFunc }
           | NRPN { name :: String, midi :: Int, range :: (Int, Int), vdefault :: Double, scalef :: RangeMapFunc }
           | SysEx { name :: String, midi :: Int, range :: (Int, Int), vdefault :: Double, scalef :: RangeMapFunc }

data ControllerShape = ControllerShape {params :: [Param],duration :: (String, Double), velocity :: (String, Double), latency :: Double}

toOscShape :: ControllerShape -> S.OscShape
toOscShape cs =
  let oscparams = [S.I "note" Nothing] ++ [S.F durn (Just durv), S.F veln (Just velv)] ++ oscparams'
      oscparams' = [S.F (name p) (Just (-1)) | p <- (params cs)]
      (durn, durv) = duration cs
      (veln, velv) = velocity cs
  in S.OscShape {S.path = "/note",
                 S.params = oscparams,
                 S.timestamp = S.MessageStamp,
                 S.cpsStamp = False,
                 S.latency = latency cs,
                 S.namedParams = False,
                 S.preamble = []
                }

passThru :: (Int, Int) -> Float -> Int
passThru (_, _) = floor -- no sanitizing of range…

mapRange :: (Int, Int) -> Float -> Int
mapRange (low, high) = floor . (+ (fromIntegral low)) . (* ratio)
  where ratio = fromIntegral $ high - low

mCC :: String -> Int -> Param
mCC n m = CC {name=n, midi=m, range=(0, 127), vdefault=0, scalef=mapRange }

mNRPN :: String -> Int -> Param
mNRPN n m = NRPN {name=n, midi=m, range=(0, 127), vdefault=0, scalef=mapRange }

mrNRPN :: String -> Int -> (Int, Int) -> Double -> Param
mrNRPN n m r d = NRPN {name=n, midi=m, range=r, vdefault=d, scalef=mapRange }

toKeynames :: ControllerShape -> [String]
toKeynames shape = map name (params shape)

ctrlN :: Num b => ControllerShape -> String -> b
ctrlN shape x = fromIntegral $ midi $ paramN shape x

paramN :: ControllerShape -> String -> Param
paramN shape x
  | x `elem` names = paramX x
  | otherwise = error $ "No such Controller param: " ++ show x
  where names = toKeynames shape
        paramX x = head paramX'
        paramX' = filter ((== x) . name) p
        p = params shape
