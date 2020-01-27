module Games exposing (..)

import Backend.HttpCommands
import DateFormat
import Dict
import Games.Types exposing (Game, GamePlayer)
import Html exposing (..)
import Html.Attributes exposing (..)
import Time exposing (Zone)
import Types exposing (GamesMsg(..), GamesSubRoute(..), Model, Msg)


fetchGames : Model -> GamesSubRoute -> ( Model, Cmd Msg )
fetchGames model sub =
    ( model, Backend.HttpCommands.games model.backend sub )


update : Model -> GamesMsg -> ( Model, Cmd Msg )
update model msg =
    let
        games =
            model.games
    in
    case msg of
        GetGames sub res ->
            case res of
                Ok list ->
                    let
                        newGames =
                            case sub of
                                AllGames ->
                                    { games | all = list }

                                GamesOfTable table ->
                                    { games | tables = Dict.insert table list games.tables }

                                GameId id ->
                                    games
                    in
                    ( { model | games = newGames }, Cmd.none )

                Err err ->
                    ( model, Cmd.none )


view : Model -> GamesSubRoute -> Html Msg
view model sub =
    div []
        [ h3 []
            [ text <|
                case sub of
                    AllGames ->
                        "All games"

                    GamesOfTable table ->
                        "Games of table " ++ table

                    GameId id ->
                        "Game #" ++ String.fromInt id
            ]
        , div [] <|
            case sub of
                AllGames ->
                    List.map (gameRow model.zone) model.games.all

                GamesOfTable table ->
                    Dict.get table model.games.tables
                        |> Maybe.map (List.map <| gameRow model.zone)
                        |> Maybe.withDefault []

                GameId id ->
                    [ text "Work in progress!"
                    , p [] [ text "Show participants and results here" ]
                    ]

        -- [ div [] [ text <| DateFormat.format "dddd, dd MMMM yyyy HH:mm:ss" model.zone game.gameStart ]
        -- ]
        ]


gameRow : Zone -> Game -> Html Msg
gameRow zone game =
    div []
        [ div []
            [ a [ href <| "games/" ++ String.fromInt game.id ] [ text <| "#" ++ String.fromInt game.id ]
            , text " "
            , span [] [ text <| DateFormat.format "dddd, dd MMMM yyyy HH:mm:ss" zone game.gameStart ]
            ]
        , blockquote []
            [ span [] [ text "Players: " ]
            , span [] [ text <| String.join ", " <| List.map .name game.players ]
            ]
        ]
