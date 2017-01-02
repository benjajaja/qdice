module Game.View exposing (view)

import Game.Types exposing (Msg(..))
import Game.Types
import Html
import Html.App
import Material
import Material.Chip as Chip
import Material.Button as Button
import Material.Icon as Icon
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
            [ Html.div []
                ((Chip.chip Html.div
                    []
                    [ Chip.text [] ("Game: " ++ (toString model.game.status)) ]
                 )
                    :: (playButtons model.mdl)
                )
            , board |> Html.App.map Types.GameMsg
            ]


playButtons : Material.Model -> List (Html.Html Types.Msg)
playButtons mdl =
    [ Button.render
        Types.Mdl
        [ 0 ]
        mdl
        [ Button.primary
        , Button.colored
        , Button.ripple
        ]
        [ Icon.i "add" ]
    , Button.render
        Types.Mdl
        [ 0 ]
        mdl
        [ Button.primary
        , Button.colored
        , Button.ripple
        ]
        [ Icon.i "remove" ]
    ]
