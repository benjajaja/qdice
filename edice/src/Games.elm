module Games exposing (..)

import Backend.HttpCommands
import DateFormat
import Dict
import Games.Types exposing (Game, GameEvent(..))
import Helpers
import Html exposing (..)
import Html.Attributes exposing (..)
import Routing exposing (routeToString)
import Snackbar exposing (toastError, toastMessage)
import Time exposing (Zone)
import Types exposing (GamesMsg(..), GamesSubRoute(..), Model, Msg, Route(..))


fetchGames : Model -> GamesSubRoute -> ( Model, Cmd Msg )
fetchGames model sub =
    let
        games =
            model.games
    in
    ( { model | games = { games | fetching = Just sub } }, Backend.HttpCommands.games model.backend sub )


update : Model -> GamesMsg -> ( Model, Cmd Msg )
update model msg =
    let
        oldGames =
            model.games

        games =
            { oldGames | fetching = Nothing }
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

                                GameId table id ->
                                    let
                                        tableGames =
                                            Dict.get table games.tables
                                                |> Maybe.withDefault []
                                                |> List.append list
                                    in
                                    { games | tables = Dict.insert table tableGames games.tables }
                    in
                    ( { model | games = newGames }, Cmd.none )

                Err err ->
                    ( { model | games = games }, toastError "Could not fetch game!" <| Helpers.httpErrorToString err )


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

                    GameId table id ->
                        "Game #" ++ String.fromInt id
            ]
        , div [] <| crumbs sub
        , div [] <|
            let
                items =
                    case sub of
                        AllGames ->
                            List.map (gameRow model.zone) model.games.all

                        GamesOfTable table ->
                            Dict.get table model.games.tables
                                |> Maybe.map (List.map <| gameRow model.zone)
                                |> Maybe.withDefault []

                        GameId table id ->
                            Dict.values model.games.tables
                                |> List.concat
                                |> Helpers.find (.id >> (==) id)
                                |> Maybe.map (gameView model.zone)
                                |> Maybe.map List.singleton
                                |> Maybe.withDefault []
            in
            case items of
                [] ->
                    case model.games.fetching of
                        Nothing ->
                            [ text "Could not find these games" ]

                        Just _ ->
                            [ text "Loading..." ]

                _ ->
                    items
        ]


crumbs : GamesSubRoute -> List (Html Msg)
crumbs sub =
    List.concat
        [ [ a [ href <| routeToString False <| GamesRoute AllGames ] [ text "Games" ] ]
        , case sub of
            GamesOfTable table ->
                [ text " > "
                , a [ href <| routeToString False <| GamesRoute sub ] [ text table ]
                ]

            GameId table id ->
                [ text " > "
                , a [ href <| routeToString False <| GamesRoute <| GamesOfTable table ] [ text table ]
                , text " > "
                , a [ href <| routeToString False <| GamesRoute sub ] [ text <| String.fromInt id ]
                ]

            _ ->
                []
        ]


gameHeader : Zone -> Game -> Html Msg
gameHeader zone game =
    div []
        [ a
            [ href <| routeToString False <| GamesRoute <| GameId game.tag game.id
            ]
            [ text <| "#" ++ String.fromInt game.id ]
        , text " "
        , span [] [ text <| DateFormat.format "dddd, dd MMMM yyyy HH:mm:ss" zone game.gameStart ]
        ]


gameRow : Zone -> Game -> Html Msg
gameRow zone game =
    div []
        [ gameHeader zone game
        , blockquote []
            [ span [] [ text "Players: " ]
            , span [] [ text <| String.join ", " <| List.map .name game.players ]
            ]
        ]


gameView : Zone -> Game -> Html Msg
gameView zone game =
    div []
        [ gameHeader zone game
        , blockquote []
            [ div [] [ text "Players: " ]
            , ul [] <|
                List.map
                    (\p ->
                        li []
                            [ div [] <|
                                if p.isBot == False then
                                    [ a [ href <| routeToString False <| ProfileRoute p.id p.name ]
                                        [ text p.name
                                        ]
                                    ]

                                else
                                    [ text p.name ]
                            ]
                    )
                    game.players
            , div [] [ text "Ledger: " ]
            , ul [] <|
                Tuple.second <|
                    List.foldl
                        foldGame
                        ( game, [] )
                        game.events
            ]
        ]


foldGame : GameEvent -> ( Game, List (Html Msg) ) -> ( Game, List (Html Msg) )
foldGame event ( game, list ) =
    case event of
        Start ->
            ( game, foldGameItem list "Game started" )

        Chat user message ->
            ( game, foldGameItem list <| user.name ++ " said: " ++ message )

        Attack player from to ->
            ( game, foldGameItem list <| player.name ++ " attacked " ++ from ++ " -> " ++ to )

        Roll from to ->
            ( game
            , foldGameItem list <|
                "Roll"
                    ++ (if List.sum from > List.sum to then
                            " succeeded"

                        else
                            " failed"
                       )
                    ++ " ("
                    ++ (String.join "," <| List.map String.fromInt from)
                    ++ " / "
                    ++ (String.join "," <| List.map String.fromInt to)
                    ++ ")"
            )

        EndTurn player ->
            ( game, foldGameItem list <| player.name ++ " ended his turn" )

        TickTurnOut ->
            ( game, foldGameItem list <| "Skipped out player" )

        TickTurnOver sitPlayerOut ->
            ( game
            , foldGameItem list <|
                "Turn time ran out"
                    ++ (if sitPlayerOut then
                            ", player is out"

                        else
                            ""
                       )
            )

        TickTurnAllOut ->
            ( game, foldGameItem list <| "All players are out" )

        SitOut player ->
            ( game, foldGameItem list <| player.name ++ " sat out" )

        SitIn player ->
            ( game, foldGameItem list <| player.name ++ " sat in" )

        ToggleReady player ready ->
            ( game, foldGameItem list <| player.name ++ " toggled ready" )

        Flag player ->
            ( game, foldGameItem list <| player.name ++ " flagged" )

        EndGame winner turnCount ->
            ( game
            , foldGameItem list <|
                (case winner of
                    Just player ->
                        player.name

                    Nothing ->
                        "Nobody"
                )
                    ++ " won the game after "
                    ++ String.fromInt turnCount
                    ++ " rounds"
            )


foldGameItem : List (Html Msg) -> String -> List (Html Msg)
foldGameItem list str =
    list
        ++ [ li []
                [ div []
                    [ text str ]
                ]
           ]
