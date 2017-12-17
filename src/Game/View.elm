module Game.View exposing (view)

import Game.Types exposing (PlayerAction(..), TableInfo)
import Game.Chat
import Game.Footer exposing (footer)
import Game.PlayerCard as PlayerCard
import Html
import Html.Attributes exposing (class, style)
import Material
import Material.Options as Options
import Material.Button as Button
import Material.Icon as Icon
import Material.Footer as Footer
import Material.List as Lists
import Types exposing (Model, Msg(..))
import Tables exposing (Table, tableList)
import Board
import Backend.Types exposing (ConnectionStatus(..))


view : Model -> Html.Html Types.Msg
view model =
    let
        board =
            Board.view model.game.board
                |> Html.map BoardMsg
    in
        Html.div [ class "edGame" ]
            [ header model
            , board
            , Html.div [ class "edPlayerChips" ] <| List.indexedMap (PlayerCard.view model) model.game.players
            , boardHistory model
            , footer model
            ]


header : Model -> Html.Html Types.Msg
header model =
    Html.div [ class "edGameHeader" ]
        [ seatButton model
        , Html.div [ class "edGameHeader__tableStatus" ]
            [ Html.span [ class "edGameHeader__chip" ]
                [ Html.text "Table "
                , Html.span [ class "edGameHeader__chip--strong" ]
                    [ Html.text <| toString model.game.table
                    ]
                ]
            , Html.span [ class "edGameHeader__chip" ]
                [ Html.text ", "
                , Html.span [ class "edGameHeader__chip--strong" ]
                    [ Html.text <|
                        (if model.game.playerSlots == 0 then
                            "∅"
                         else
                            toString model.game.playerSlots
                        )
                    ]
                , Html.text " player game is "
                , Html.span [ class "edGameHeader__chip--strong" ]
                    [ Html.text <| toString model.game.status
                    ]
                ]
            ]
        , Html.div [ class "edGameHeader__buttons" ]
            [ endTurnButton model
            ]
        ]


seatButton : Model -> Html.Html Types.Msg
seatButton model =
    let
        canPlay =
            case model.backend.status of
                Online ->
                    case model.user of
                        Types.Anonymous ->
                            False

                        Types.Logged user ->
                            True

                _ ->
                    False

        ( label, action ) =
            (if isPlayerInGame model then
                (if model.game.status == Game.Types.Playing then
                    ( "Sit out", SitOut )
                 else
                    ( "Leave game", Leave )
                )
             else
                ( "Join game", Join )
            )
    in
        Button.render
            Types.Mdl
            [ 0 ]
            model.mdl
            [ Button.raised
            , Button.colored
            , Button.ripple
            , Options.cs "edGameHeader__button"
            , Options.onClick <| GameCmd action
            , Options.disabled <| not canPlay
            ]
            [ Html.text label ]


endTurnButton : Model -> Html.Html Types.Msg
endTurnButton model =
    Button.render
        Types.Mdl
        [ 1 ]
        model.mdl
        [ Button.colored
        , Button.ripple
        , Options.cs "edGameHeader__button"
        , Options.onClick <| GameCmd EndTurn
        , Options.disabled <| not model.game.hasTurn
        ]
        [ Html.text "End turn" ]


boardHistory : Model -> Html.Html Types.Msg
boardHistory model =
    Html.div []
        [ Game.Chat.chatBox model ]


isPlayerInGame : Model -> Bool
isPlayerInGame model =
    case model.user of
        Types.Anonymous ->
            False

        Types.Logged user ->
            List.map (.id) model.game.players
                |> List.any (\id -> id == user.id)
