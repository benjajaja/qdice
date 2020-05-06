module Routing exposing (findBestTable, fragmentUrl, goToBestTable, navigateTo, parseLocation, replaceNavigateTo, routeEnterCmd)

import Backend.HttpCommands exposing (profile)
import Browser.Navigation exposing (Key)
import Comments
import Game.Types exposing (GameStatus(..), TableInfo)
import Games
import LeaderBoard.State exposing (fetchLeaderboard)
import Profile
import Routing.String exposing (routeToString)
import Tables exposing (Table)
import Types exposing (GamesSubRoute(..), Model, Msg(..), Route(..), StaticPage(..), User(..))
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
        , map CommentsRoute (s "posts")
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
                        goToBestTable model Nothing True

                      else
                        Cmd.none
                    )

                GamesRoute sub ->
                    Games.enter model sub

                _ ->
                    ( model
                    , Cmd.none
                    )
    in
    Comments.routeEnter route model_ cmd


findBestTable : Model -> Maybe Table -> Maybe Table
findBestTable model current =
    List.filter
        (\i ->
            if i.status == Playing then
                i.botCount > 0

            else
                i.playerCount > 0
        )
        model.tableList
        |> List.filter
            (case model.user of
                Logged user ->
                    \i -> i.points <= user.points

                Anonymous ->
                    \i -> i.points == 0
            )
        |> List.head
        |> Maybe.map .table
        |> Maybe.andThen
            (\best ->
                case current of
                    Nothing ->
                        Just best

                    Just c ->
                        if best == c then
                            Nothing

                        else
                            Just best
            )


goToBestTable : Model -> Maybe Table -> Bool -> Cmd Msg
goToBestTable model current replace =
    let
        elegible =
            findBestTable model current

        cmd =
            if not replace && (elegible == Nothing || elegible == current) then
                Cmd.none

            else
                Maybe.withDefault "Planeta" elegible
                    |> GameRoute
                    |> (if replace then
                            replaceNavigateTo

                        else
                            navigateTo
                       )
                        False
                        model.key
    in
    cmd


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
