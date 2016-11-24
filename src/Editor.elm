module Main exposing (..)

import Window
import Html
import Html.Events as Html
import Html.App as App
import String
import Dict
import Task
import Board
import Land


main : Program Never
main =
    App.program
        { init = init
        , view = view
        , update = update
        , subscriptions =
            subscriptions
            --\_ -> Window.resizes sizeToMsg
        }


type Msg
    = Resize ( Int, Int )
    | Board Board.Msg
    | AddLand
    | RandomLandColor Land.Land Land.Color


type alias Model =
    { size : ( Int, Int )
    , board : Board.Model
    , userMap : List Land.Land
    , output : String
    }


init : ( Model, Cmd Msg )
init =
    let
        ( board, boardFx ) =
            Board.init
    in
        ( Model ( 0, 0 ) board [] ""
        , Cmd.batch
            [ Cmd.map Board boardFx
            , Task.perform (\a -> Debug.log "?" a) sizeToMsg Window.size
            ]
        )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        { size, board, userMap } =
            model
    in
        case msg of
            Resize size ->
                ( { model | board = { board | size = size } }, Cmd.none )

            Board msg ->
                let
                    ( board, boardCmds ) =
                        Board.update msg board
                in
                    ( { model | board = board }, Cmd.map Board boardCmds )

            AddLand ->
                addSelectedLand model

            RandomLandColor land color ->
                Land.setColor board.map land color |> updateMap model Cmd.none


updateMap : Model -> Cmd Msg -> Land.Map -> ( Model, Cmd Msg )
updateMap model cmd map =
    let
        { board } =
            model
    in
        ( { model | board = { board | map = map } }, cmd )


view : Model -> Html.Html Msg
view model =
    let
        header =
            Html.h1 [] [ Html.text "eDice" ]

        board' =
            Board.view model.board

        button' =
            Html.button [ Html.onClick AddLand ] [ Html.text "Add" ]

        pre =
            Html.pre [] [ Html.text model.output ]
    in
        Html.div []
            [ header
            , App.map Board board'
            , button'
            , pre
            ]


subscriptions : Model -> Sub Msg
subscriptions model =
    Window.resizes sizeToMsg


addSelectedLand : Model -> ( Model, Cmd Msg )
addSelectedLand model =
    let
        { size, board, userMap } =
            model

        map =
            board.map

        selection : List Land.Land
        selection =
            List.filter (\l -> l.color == Land.Editor) map

        ( map', land ) =
            case selection of
                [] ->
                    ( map, Nothing )

                _ ->
                    case List.filter (\l -> l.color /= Land.Editor) map of
                        [] ->
                            ( map, Nothing )

                        m ->
                            let
                                _ =
                                    Debug.log "selection" (selection)

                                land : Land.Land
                                land =
                                    Land.concat selection
                            in
                                ( Land.append m { land | color = Land.Neutral }, Just land )

        userMap' =
            case land of
                Nothing ->
                    userMap

                Just land ->
                    List.append (filterDupes userMap land) [ land ]

        board' =
            { board | map = checkDupes map' }
    in
        ( { model | board = board', userMap = userMap', output = mapElm userMap' }
        , case land of
            Just l ->
                Land.randomPlayerColor (RandomLandColor l)

            Nothing ->
                Cmd.none
        )


checkDupes : Land.Map -> Land.Map
checkDupes map =
    let
        cells =
            List.map .hexagons map |> List.concat
    in
        if
            List.any
                (\l ->
                    List.any
                        (\c ->
                            let
                                matches =
                                    List.filter (\o -> o == c) cells

                                is =
                                    (List.length matches) > 1

                                _ =
                                    if is then
                                        Debug.log "dupe at:" ( c, List.length matches )
                                    else
                                        ( c, 0 )
                            in
                                is
                        )
                        l.hexagons
                )
                map
        then
            Debug.crash "dupes!"
        else
            map


filterDupes : List Land.Land -> Land.Land -> List Land.Land
filterDupes list land =
    List.filter
        (\l ->
            List.any (\c -> List.member c l.hexagons) land.hexagons
                |> not
        )
        list


sizeToMsg : Window.Size -> Msg
sizeToMsg size =
    Debug.log "size" (Resize ( size.width, size.height ))


mapElm : List Land.Land -> String
mapElm map =
    case map of
        [] ->
            "{- empty -}"

        hd :: _ ->
            List.map
                (\row ->
                    let
                        cells =
                            List.map (\col -> ( Land.at map ( col, row ), col )) [0..30]

                        offset =
                            if row % 2 == 0 then
                                ""
                            else
                                "  "
                    in
                        offset
                            ++ (String.join "" <|
                                    List.map
                                        (\c ->
                                            if fst c == -1 then
                                                "    "
                                            else
                                                let
                                                    symbol =
                                                        fst c |> indexSymbol |> String.fromChar
                                                in
                                                    " " ++ symbol ++ symbol ++ " "
                                        )
                                        cells
                               )
                )
                [0..20]
                |> String.join "\n"


symbolDict : Dict.Dict Int Char
symbolDict =
    List.indexedMap (,)
        [ '💩'
        , '🍋'
        , '🔥'
        , '😃'
        , '🐙'
        , '🐸'
        , '☢'
        , '😺'
        , '🐵'
        , '❤'
        , '🚩'
        , '🚬'
        , '🚶'
        , '💎'
        , '⁉'
        , '⌛'
        , '☀'
        , '☁'
        , '☕'
        , '🎩'
        , '♨'
        , '👙'
        , '⚠'
        , '⚡'
        , '⚽'
        , '⛄'
        , '⭐'
        , '🌙'
        , '🌴'
        , '🌵'
        , '🍀'
        , '💥'
        , '🍒'
        , '🍩'
        , '🍷'
        , '🍺'
        , '🍏'
        , '🎵'
        , '🐟'
        , '🐧'
        , '🐰'
        , '🍉'
        , '👀'
        , '👍'
        , '👑'
        , '👻'
        , '💊'
        , '💋'
        , '💣'
        , '💧'
        , '💀'
        , '🌎'
        , '🐊'
        , '✊'
        , '⛔'
        , '🍌'
        ]
        |> Dict.fromList


indexSymbol : Int -> Char
indexSymbol i =
    case Dict.get i symbolDict of
        Just c ->
            c

        Nothing ->
            ' '
