module Games exposing (..)

import Backend.HttpCommands
import Board.Colors exposing (baseCssRgb)
import Comments
import DateFormat
import Dict
import Games.Replayer exposing (gameReplayer)
import Games.Replayer.Types exposing (ReplayerModel)
import Games.Types exposing (Game, GameEvent(..), GamePlayer)
import Helpers exposing (dataTestId)
import Html exposing (..)
import Html.Attributes exposing (..)
import Placeholder exposing (Placeheld(..))
import Routing.String exposing (link, routeToString)
import Snackbar exposing (toastError)
import Time exposing (Zone)
import Types exposing (GamesMsg(..), GamesSubRoute(..), Model, Msg, Route(..))


fetchGames : Model -> GamesSubRoute -> ( Model, Cmd Msg )
fetchGames model sub =
    ( { model | games = Placeholder.toFetching model.games }
    , Backend.HttpCommands.games model.backend sub
    )


update : Model -> GamesMsg -> ( Model, Cmd Msg )
update model msg =
    case msg of
        GetGames sub res ->
            case res of
                Ok list ->
                    let
                        newGames =
                            case sub of
                                AllGames ->
                                    model.games
                                        |> Placeholder.value
                                        |> (\games ->
                                                Fetched { games | all = list }
                                           )

                                GamesOfTable table ->
                                    model.games
                                        |> Placeholder.value
                                        |> (\games ->
                                                Fetched { games | tables = Dict.insert table list games.tables }
                                           )

                                GameId table id ->
                                    model.games
                                        |> Placeholder.value
                                        |> (\games ->
                                                let
                                                    tableGames =
                                                        Dict.get table games.tables
                                                            |> Maybe.withDefault []
                                                            |> List.append list
                                                in
                                                Fetched { games | tables = Dict.insert table tableGames games.tables }
                                           )

                        model_ =
                            { model | games = newGames }
                    in
                    case sub of
                        GameId table id ->
                            case list of
                                [ game ] ->
                                    ( { model_ | replayer = Just <| Games.Replayer.init game }, Cmd.none )

                                _ ->
                                    ( model_, toastError "Game not found" "game list was not a singleton" )

                        _ ->
                            ( model_, Cmd.none )

                Err err ->
                    ( { model
                        | games =
                            model.games
                                |> Placeholder.value
                                |> (\games ->
                                        Error (Helpers.httpErrorToString err) games
                                   )
                      }
                    , toastError "Could not fetch game!" <| Helpers.httpErrorToString err
                    )


enter : Model -> GamesSubRoute -> ( Model, Cmd Msg )
enter model sub =
    let
        games =
            model.games

        model_ =
            { model | games = Placeholder.toFetching model.games }

        cmd =
            Backend.HttpCommands.games model.backend sub
    in
    ( model_, cmd )


view : Model -> GamesSubRoute -> Html Msg
view model sub =
    div [] <|
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
            case model.games of
                Placeholder _ ->
                    [ text "Waiting..." ]

                Fetching _ ->
                    [ text "Loading..." ]

                Fetched games ->
                    case sub of
                        AllGames ->
                            case games.all of
                                [] ->
                                    [ text "No games found" ]

                                _ ->
                                    List.map (gameRow model.zone) games.all

                        GamesOfTable table ->
                            Dict.get table games.tables
                                |> Maybe.map (List.map <| gameRow model.zone)
                                |> Maybe.map
                                    (\rows ->
                                        case rows of
                                            [] ->
                                                [ text "No games yet" ]

                                            _ ->
                                                rows
                                    )
                                |> Maybe.withDefault [ text "Games not found" ]

                        GameId table id ->
                            Dict.values games.tables
                                |> List.concat
                                |> Helpers.find (.id >> (==) id)
                                |> Maybe.map (gameView model.zone model.replayer)
                                |> Maybe.map List.singleton
                                |> Maybe.withDefault [ text "Game not found." ]

                Error err _ ->
                    [ text <| "Error: " ++ err ]
        ]
            ++ (case sub of
                    AllGames ->
                        []

                    GamesOfTable table ->
                        []

                    GameId table id ->
                        [ Comments.view model.zone model.user model.comments <| Comments.gameComments table id ]
               )


crumbs : GamesSubRoute -> List (Html Msg)
crumbs sub =
    List.concat
        [ [ link "Games" <| GamesRoute AllGames ]
        , case sub of
            GamesOfTable table ->
                [ text " > "
                , link table <| GamesRoute sub
                ]

            GameId table id ->
                [ text " > "
                , link table <| GamesRoute <| GamesOfTable table
                , text " > "
                , link ("#" ++ String.fromInt id) <| GamesRoute <| sub
                ]

            _ ->
                []
        ]


gameHeader : Zone -> Game -> Html Msg
gameHeader zone game =
    div []
        [ a
            [ href <| routeToString False <| GamesRoute <| GameId game.tag game.id
            , dataTestId <| "game-entry-" ++ String.fromInt game.id
            ]
            [ text <| "#" ++ String.fromInt game.id ]
        , text <| " on table " ++ game.tag ++ " "
        , span [] [ text <| DateFormat.format "dddd, dd MMMM yyyy HH:mm:ss" zone game.gameStart ]
        ]


gameRow : Zone -> Game -> Html Msg
gameRow zone game =
    div []
        [ gameHeader zone game
        , blockquote [] <|
            [ span [] [ text "Players: " ]
            ]
                ++ playersList game.players
        ]


playersList : List GamePlayer -> List (Html Msg)
playersList players =
    Helpers.join (text ", ") <|
        List.map
            (\p ->
                (if p.isBot then
                    em

                 else
                    a
                )
                    (style "color" (baseCssRgb p.color)
                        :: (if not p.isBot then
                                [ Routing.String.linkAttr <| ProfileRoute p.id p.name ]

                            else
                                []
                           )
                    )
                    [ text <| p.name ]
            )
            players


gameView : Zone -> Maybe ReplayerModel -> Game -> Html Msg
gameView zone replayer game =
    div []
        [ gameHeader zone game
        , div [] <|
            [ span [] [ text "Starting players: " ] ]
                ++ playersList game.players
        , gameReplayer replayer game
        ]
