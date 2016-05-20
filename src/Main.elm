import Window
import Html exposing (Html, button, div, text)
import Html.App as Html
import Html.Events exposing (onClick)

import View exposing (..)
import Land exposing (..)

main =
  Html.beginnerProgram
    { model = model
    , view = view
    , update = update
    }

type alias Model = Map
model = testLand

type Msg = A | B

update : Msg -> Model -> Model
update msg model = model

view : Model -> Html Msg
view model =
  div [] [
    Html.h1 [] [Html.text "eDice"]
    , board (800, 800) testLand
    -- , roundRect
  ]
-- view : (Int, Int) -> Html
-- view size =
--   Html.main' [] [
--     Html.h1 [] [Html.text "eDice"]
--     -- , board size testLand |> Html.fromElement
--     , roundRect
--   ]