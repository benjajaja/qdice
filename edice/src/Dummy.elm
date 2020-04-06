{- This is a dummy main file, to cache package.elm-lang.org.
   The `Dockerfile` has a step that only copies this file and `elm.json`,
   then runs `elm make src/Dummy.elm` which generates `~/.elm` and caches
   the docker step. The cache is invalidated only when `elm.json` changes.
-}


module Dummy exposing (main)

import Browser
import Html exposing (div)


main =
    Browser.sandbox { init = (), update = \_ -> \b -> b, view = \m -> div [] [] }
