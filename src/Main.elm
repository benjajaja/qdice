import Window
import Graphics.Element exposing (..)
import Html exposing (Html)

import View exposing (..)
import Land exposing (..)

main : Signal Html
main =
  Signal.map view Window.dimensions

view : (Int, Int) -> Html
view (w,h) =
  Html.main' [] [
    Html.h1 [] [Html.text "eDice"]
    , board (w, h) testLand |> Html.fromElement
  ]