module Game.View exposing (view)

import Game.Types exposing (PlayerAction(..), TableInfo)
import Game.Chat
import Game.Footer exposing (footer)
import Html
import Html.Attributes exposing (class, style)
import Svg
import Svg.Attributes
import Time exposing (inMilliseconds)
import Material
import Material.Options as Options
import Material.Elevation as Elevation
import Material.Chip as Chip
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
            , Html.div [ class "edPlayerChips" ] <| List.indexedMap (playerChip model) model.game.players
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


playerChip : Model -> Int -> Game.Types.Player -> Html.Html Types.Msg
playerChip model index player =
    Options.div
        [ Options.cs ("edPlayerChip edPlayerChip--" ++ (toString player.color))
        , if index == model.game.turnIndex then
            Elevation.e6
          else
            Elevation.e2
        ]
        [ playerImageProgress model index player
        , Html.div [ class "edPlayerChip__name" ] [ Html.text player.name ]
          --, Html.div []
          --[ playerChipProgress model index
          --]
        , Html.div [ class "edPlayerChip__gameStats" ]
            [ Html.span [ class "edPlayerChip__gameStats__item" ]
                [ Html.text <| "⬢ " ++ toString player.gameStats.totalLands ]
            , Html.span [ class "edPlayerChip__gameStats__item" ]
                [ Html.text <|
                    ("⚂ "
                        ++ toString player.gameStats.currentDice
                        ++ (if player.reserveDice > 0 then
                                " + " ++ toString player.reserveDice
                            else
                                ""
                           )
                    )
                ]
            ]
        ]


playerImageProgress model index player =
    Html.div [ class "edPlayerChip__picture" ]
        [ playerCircleProgress <|
            (if index == model.game.turnIndex then
                1.0 - turnProgress model
             else
                0.0
            )
        , Html.div
            [ class "edPlayerChip__picture__image"
            , style
                [ ( "background-image", ("url(" ++ player.picture ++ ")") )
                , ( "background-size", "cover" )
                ]
            ]
            []
        ]


playerCircleProgress progress =
    let
        x =
            toString <| cos (2 * pi * progress)

        y =
            toString <| sin (2 * pi * progress)

        progressStep =
            toString <|
                floor (progress * 100 / 20)
                    * 20
    in
        Svg.svg
            [ Svg.Attributes.viewBox "-1 -1 2 2"
            , Svg.Attributes.style "transform: rotate(-0.25turn)"
            , Svg.Attributes.class <| "edPlayerChip_clock edPlayerChip_clock--" ++ progressStep
            ]
            [ Svg.path
                [ Svg.Attributes.d
                    ("M 1 0"
                        ++ " A 1 1 0 "
                        ++ (if progress > 0.5 then
                                "1"
                            else
                                "0"
                           )
                        ++ " 1 "
                        ++ x
                        ++ " "
                        ++ y
                        ++ " L 0 0"
                    )
                ]
                []
            ]


playerChipProgress model index =
    let
        hasTurn =
            index == model.game.turnIndex

        progress =
            (turnProgress model) * 100

        progressStep =
            floor (progress / 10) * 10
    in
        Html.div
            [ class ("edPlayerChip__progress edPlayerChip__progress--" ++ (toString progressStep))
            , style
                [ ( "width"
                  , (if hasTurn then
                        (toString progress) ++ "%"
                     else
                        "0%"
                    )
                  )
                ]
            ]
            []


turnProgress : Model -> Float
turnProgress model =
    let
        turnTime =
            toFloat model.game.turnDuration

        timestamp =
            inMilliseconds model.time / 1000

        turnStarted =
            toFloat model.game.turnStarted
    in
        max 0.0 <|
            min 1 <|
                (turnTime - (timestamp - turnStarted))
                    / turnTime


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
