module Games exposing (..)

import Backend.HttpCommands
import Board.Colors exposing (baseCssRgb, colorName)
import Comments
import DateFormat
import Dict
import Game.Chat
import Games.Replayer exposing (gameReplayer)
import Games.Replayer.Types exposing (ReplayerModel)
import Games.Types exposing (Game, GameEvent(..), GamePlayer)
import Helpers exposing (dataTestId)
import Html exposing (..)
import Html.Attributes exposing (..)
import Routing.String exposing (link, routeToString)
import Snackbar exposing (toastError)
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
                    ( { model | games = games }, toastError "Could not fetch game!" <| Helpers.httpErrorToString err )


enter : Model -> GamesSubRoute -> ( Model, Cmd Msg )
enter model sub =
    let
        games =
            model.games

        model_ =
            { model | games = { games | fetching = Just sub } }

        cmd =
            Backend.HttpCommands.games model.backend sub
    in
    -- case sub of
    -- GameId table id ->
    -- ( { model_ | replayer = Just <| Games.Replayer.init table }, cmd )
    --
    -- _ ->
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
                                |> Maybe.map (gameView model.zone model.replayer)
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
    List.foldl
        (\p l ->
            let
                el =
                    (if p.isBot then
                        em

                     else
                        a
                    )
                        ([ style "color" (baseCssRgb p.color)
                         ]
                            ++ (if not p.isBot then
                                    Routing.String.linkAttrs <| ProfileRoute p.id p.name

                                else
                                    []
                               )
                        )
                        [ text <| p.name ]
            in
            case l of
                [] ->
                    [ el ]

                _ ->
                    l ++ [ text ", ", el ]
        )
        []
        players


gameView : Zone -> Maybe ReplayerModel -> Game -> Html Msg
gameView zone replayer game =
    div []
        [ gameHeader zone game
        , div [] <|
            [ span [] [ text "Players: " ] ]
                ++ playersList game.players
        , gameReplayer replayer game
        , div [] [ text "Ledger: " ]
        , ul [] <|
            Tuple.second <|
                List.foldl
                    foldGame
                    ( game, [] )
                    game.events
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

        EndTurn id landDice reserveDice _ player ->
            ( game
            , foldGameItemSpecial list <|
                div []
                    [ text <|
                        player.name
                            ++ " ended his turn, receiving "
                            ++ String.fromInt
                                (List.length landDice + reserveDice)
                            ++ " dice"

                    -- , div [] [ img [ src <| "http://localhost/screenshots/screenshot_" ++ String.fromInt id ++ ".png" ] [] ]
                    ]
            )

        -- ( game, foldGameItem list <| player.name ++ " ended his turn" )
        SitOut player ->
            ( game, foldGameItem list <| player.name ++ " sat out" )

        SitIn player ->
            ( game, foldGameItem list <| player.name ++ " sat in" )

        ToggleReady player ready ->
            ( game
            , foldGameItem list <|
                player.name
                    ++ " toggled ready -> "
                    ++ (if ready then
                            "yes"

                        else
                            "no"
                       )
            )

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

        Unknown str ->
            ( game, foldGameItem list <| "Unknown event \"" ++ str ++ "\"" )


foldGameItem : List (Html Msg) -> String -> List (Html Msg)
foldGameItem list str =
    list
        ++ [ li []
                [ div [ dataTestId "game-event" ]
                    [ text str ]
                ]
           ]


foldGameItemSpecial : List (Html Msg) -> Html Msg -> List (Html Msg)
foldGameItemSpecial list element =
    list
        ++ [ li []
                [ element ]
           ]
