module Game.View exposing (view)

import Game.Types exposing (Msg(..))
import Game.Types
import Html
import Html.App
import Material.Chip as Chip
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
            [ Chip.span []
                [ Chip.content []
                    [ Html.text "Game" ]
                ]
            , board
            ]
            |> Html.App.map Types.GameMsg
