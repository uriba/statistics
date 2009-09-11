{-# LANGUAGE BangPatterns #-}
-- |
-- Module    : Statistics.Math
-- Copyright : (c) 2009 Bryan O'Sullivan
-- License   : BSD3
--
-- Maintainer  : bos@serpentine.com
-- Stability   : experimental
-- Portability : portable
--
-- Mathematical functions for statistics.

module Statistics.Math
    (
    -- * Functions
      chebyshev
    , choose
    -- ** The Gamma function
    , incompleteGamma
    , logGamma
    , logGammaL
    -- * References
    -- $references
    ) where

import Data.Array.Vector
import Statistics.Constants (m_sqrt_2_pi)
import Statistics.Distribution (cumulative)
import Statistics.Distribution.Normal (standard)

data C = C {-# UNPACK #-} !Double {-# UNPACK #-} !Double {-# UNPACK #-} !Double

-- | Evaluate a series of Chebyshev polynomials. Uses Clenshaw's
-- algorithm.
chebyshev :: Double             -- ^ Parameter of each function.
          -> UArr Double        -- ^ Coefficients of each polynomial
          -- term, in increasing order.
          -> Double
chebyshev x a = fini . foldlU step (C 0 0 0) .
                enumFromThenToU (lengthU a - 1) (-1) $ 0
    where step (C u v w) k = C (x2 * v - w + indexU a k) u v
          fini (C u _ w)   = (u - w) / 2
          x2               = x * 2

-- | The binomial coefficient.
--
-- > 7 `choose` 3 == 35
choose :: Int -> Int -> Int
n `choose` k
    | k > n = 0
    | otherwise = ceiling . foldlU go 1 . enumFromToU 1 $ k'
    where go a i = a * (nk + j) / j
              where j = fromIntegral i :: Double
          k' | k > n `div` 2 = n - k
             | otherwise     = k
          nk = fromIntegral (n - k')
{-# INLINE choose #-}

-- | Compute the incomplete gamma integral function, &#947;(/s/,/x/).
-- Uses Algorithm AS 239 by Shea.
incompleteGamma :: Double
                -> Double
                -> Double
incompleteGamma x p
    | x < 0 || p <= 0 = 1/0
    | x == 0          = 0
    | p >= 1000       = norm (3 * sqrt p * ((x/p) ** (1/3) + 1/(9*p) - 1))
    | x >= 1e8        = 0
    | x <= 1 || x < p = let a = p * log x - x - logGamma (p + 1)
                            g = a + log (pearson p 1 1)
                        in if g > limit then exp g else 0
    | otherwise       = let g = p * log x - x - logGamma p + log cf
                        in if g > limit then 1 - exp g else 1
  where
    norm = cumulative standard
    pearson !a !c !g
        | c' <= tolerance = g'
        | otherwise       = pearson a' c' g'
        where a' = a + 1
              c' = c * x / a'
              g' = g + c'
    cf = let a = 1 - p
             b = a + x + 1
             p3 = x + 1
             p4 = x * b
         in contFrac a b 0 1 x p3 p4 (p3/p4)
    contFrac !a !b !c !p1 !p2 !p3 !p4 !g
        | abs (g - rn) <= min tolerance (tolerance * rn) = g
        | otherwise = contFrac a' b' c' (f p3) (f p4) (f p5) (f p6) rn
        where a' = a + 1
              b' = b + 2
              c' = c + 1
              an = a' * c'
              p5 = b' * p3 - an * p1
              p6 = b' * p4 - an * p2
              rn = p5 / p6
              f n | abs p5 > overflow = n / overflow
                  | otherwise         = n
    limit     = -88
    tolerance = 1e-14
    overflow  = 1e37

-- Adapted from http://people.sc.fsu.edu/~burkardt/f_src/asa245/asa245.html

-- | Compute the logarithm of the gamma function, &#915;(/x/).  Uses
-- Algorithm AS 245 by Macleod.
--
-- Gives an accuracy of 10&#8211;12 significant decimal digits, except
-- for small regions around /x/ = 1 and /x/ = 2, where the function
-- goes to zero.  For greater accuracy, use 'logGammaL'.
--
-- Returns &#8734; if the input is outside of the range (0 < /x/
-- &#8804; 1e305).
logGamma :: Double -> Double
logGamma x = r
  where
    !r | x <= 0  = 1/0
       | x < 1.5 = a + c *
                   ((((r1_4 * b + r1_3) * b + r1_2) * b + r1_1) * b + r1_0) /
                   ((((b + r1_8) * b + r1_7) * b + r1_6) * b + r1_5)
        | x < 4   = (x - 2) *
                    ((((r2_4 * x + r2_3) * x + r2_2) * x + r2_1) * x + r2_0) /
                    ((((x + r2_8) * x + r2_7) * x + r2_6) * x + r2_5)
        | x < 12  = ((((r3_4 * x + r3_3) * x + r3_2) * x + r3_1) * x + r3_0) /
                    ((((x + r3_8) * x + r3_7) * x + r3_6) * x + r3_5)
        | x > 5.1e5 = k
        | otherwise = k + x1 *
                      ((r4_2 * x2 + r4_1) * x2 + r4_0) /
                      ((x2 + r4_4) * x2 + r4_3)
    a :*: b :*: c
        | x < 0.5   = -y :*: x + 1 :*: x
        | otherwise = 0  :*: x     :*: x - 1

    y      = log x
    k      = x * (y-1) - 0.5 * y + alr2pi
    alr2pi = 0.918938533204673

    x1 = 1 / x
    x2 = x1 * x1

    r1_0 = -2.66685511495; r1_1 = -24.4387534237; r1_2 = -21.9698958928
    r1_3 = 11.1667541262; r1_4 = 3.13060547623; r1_5 = 0.607771387771
    r1_6 = 11.9400905721; r1_7 = 31.4690115749; r1_8 = 15.2346874070

    r2_0 = -78.3359299449; r2_1 = -142.046296688; r2_2 = 137.519416416
    r2_3 = 78.6994924154; r2_4 = 4.16438922228; r2_5 = 47.0668766060
    r2_6 = 313.399215894; r2_7 = 263.505074721; r2_8 = 43.3400022514

    r3_0 = -2.12159572323; r3_1 = 2.30661510616; r3_2 = 2.74647644705
    r3_3 = -4.02621119975; r3_4 = -2.29660729780; r3_5 = -1.16328495004
    r3_6 = -1.46025937511; r3_7 = -2.42357409629; r3_8 = -5.70691009324

    r4_0 = 0.279195317918525; r4_1 = 0.4917317610505968;
    r4_2 = 0.0692910599291889; r4_3 = 3.350343815022304
    r4_4 = 6.012459259764103

data L = L {-# UNPACK #-} !Double {-# UNPACK #-} !Double

-- | Compute the logarithm of the gamma function, &#915;(/x/).  Uses a
-- Lanczos approximation.
--
-- This function is slower than 'logGamma', but gives 14 or more
-- significant decimal digits of accuracy, except around /x/ = 1 and
-- /x/ = 2, where the function goes to zero.
--
-- Returns &#8734; if the input is outside of the range (0 < /x/
-- &#8804; 1e305).
logGammaL :: Double -> Double
logGammaL x
    | x <= 0    = 1/0
    | otherwise = fini . foldlU go (L 0 (x+7)) $ a
    where fini (L l _) = log (l+a0) + log m_sqrt_2_pi - x65 + (x-0.5) * log x65
          go (L l t) k = L (l + k / t) (t-1)
          x65 = x + 6.5
          a0  = 0.9999999999995183
          a   = toU [ 0.1659470187408462e-06
                    , 0.9934937113930748e-05
                    , -0.1385710331296526
                    , 12.50734324009056
                    , -176.6150291498386
                    , 771.3234287757674
                    , -1259.139216722289
                    , 676.5203681218835
                    ]

-- $references
--
-- * Clenshaw, C.W. (1962) Chebyshev series for mathematical
--   functions. /National Physical Laboratory Mathematical Tables 5/,
--   Her Majesty's Stationery Office, London.
--
-- * Lanczos, C. (1964) A precision approximation of the gamma
--   function.  /SIAM Journal on Numerical Analysis B/
--   1:86&#8211;96. <http://www.jstor.org/stable/2949767>
--
-- * Macleod, A.J. (1989) Algorithm AS 245: A robust and reliable
--   algorithm for the logarithm of the gamma function.
--   /Journal of the Royal Statistical Society, Series C (Applied Statistics)/
--   38(2):397&#8211;402. <http://www.jstor.org/stable/2348078>
--
-- * Shea, B. (1988) Algorithm AS 239: Chi-squared and incomplete
--   gamma integral. /Applied Statistics/
--   37(3):466&#8211;473. <http://www.jstor.org/stable/2347328>