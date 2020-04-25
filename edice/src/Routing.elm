module Routing exposing (fragmentUrl, goToBestTable, navigateTo, parseLocation, replaceNavigateTo, routeEnterCmd)

import Backend.HttpCommands exposing (profile)
import Browser.Navigation exposing (Key)
import Comments
import LeaderBoard.State exposing (fetchLeaderboard)
import Profile
import Routing.String exposing (routeToString)
import Types exposing (GamesSubRoute(..), Model, Msg, Route(..), StaticPage(..))
import Url exposing (Url, percentDecode)
import Url.Parser exposing (..)


parseLocation : Url -> Route
parseLocation url =
    parse matchers url
        |> Maybe.withDefault NotFoundRoute


matchers : Parser (Route -> a) a
matchers =
    oneOf
        [ map HomeRoute top
        , map StaticPageRoute (s "static" </> staticPageMatcher)
        , map MyProfileRoute (s "me")
        , map TokenRoute (s "token" </> string)
        , map ProfileRoute (s "profile" </> string </> string)
        , map LeaderBoardRoute (s "leaderboard")
        , map GamesRoute
            (s "games"
                </> oneOf
                        [ map AllGames top
                        , map GameId (string </> int)
                        , map GamesOfTable string
                        ]
            )
        , tableMatcher
        ]


staticPageMatcher : Parser (StaticPage -> a) a
staticPageMatcher =
    custom "STATIC_PAGE" <|
        \segment ->
            case segment of
                "help" ->
                    Just Help

                "about" ->
                    Just About

                _ ->
                    Nothing


tableMatcher : Parser (Route -> a) a
tableMatcher =
    custom "GAME" <|
        \segment ->
            percentDecode segment |> Maybe.map GameRoute


navigateTo : Bool -> Key -> Route -> Cmd Msg
navigateTo useHash key route =
    Browser.Navigation.pushUrl key <| routeToString useHash route


replaceNavigateTo : Bool -> Key -> Route -> Cmd Msg
replaceNavigateTo useHash key route =
    Browser.Navigation.replaceUrl key <| routeToString useHash route


routeEnterCmd : Model -> Route -> ( Model, Cmd Msg )
routeEnterCmd model route =
    let
        ( model_, cmd ) =
            case route of
                LeaderBoardRoute ->
                    fetchLeaderboard model model.leaderBoard.page

                ProfileRoute id _ ->
                    profile model Profile.init id

                HomeRoute ->
                    ( model
                    , if List.length model.tableList > 0 then
                        goToBestTable model

                      else
                        Cmd.none
                    )

                GamesRoute sub ->
                    let
                        games =
                            model.games
                    in
                    ( { model | games = { games | fetching = Just sub } }, Backend.HttpCommands.games model.backend sub )

                _ ->
                    ( model
                    , Cmd.none
                    )
    in
    Comments.routeEnter route model_ cmd


goToBestTable : Model -> Cmd Msg
goToBestTable model =
    case List.head <| List.filter hasSomePlayers model.tableList of
        Just bestTable ->
            replaceNavigateTo model.zip model.key <| GameRoute bestTable.table

        Nothing ->
            replaceNavigateTo model.zip model.key <| GameRoute "Planeta"


hasSomePlayers table =
    not table.params.twitter
        && table.playerCount
        > 0


fragmentUrl : Url -> Url
fragmentUrl =
    fixPathQuery << pathFromFragment


pathFromFragment : Url -> Url
pathFromFragment url =
    { url | path = Maybe.withDefault "" url.fragment, fragment = Nothing }


fixPathQuery : Url -> Url
fixPathQuery url =
    let
        ( newPath, newQuery ) =
            case String.split "?" url.path of
                path :: query :: _ ->
                    ( path, Just query )

                _ ->
                    ( url.path, url.query )
    in
    { url | path = newPath, query = newQuery }
