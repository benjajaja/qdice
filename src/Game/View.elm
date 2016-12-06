module Game.View exposing (view)

import Game.Types exposing (Msg(..))
import Game.Types
import Html
import Html.App
import Types exposing (Model, Msg)
import Board


-- import Board.Types exposing (Msg(..))
-- import Land


view : Model -> Html.Html Types.Msg
view model =
    let
        board =
            Board.view model.game.board
                |> Html.App.map BoardMsg
    in
        Html.div []
            [ Html.div [] [ Html.text "Game mode" ]
            , board
            ]
            |> Html.App.map Types.GameMsg
