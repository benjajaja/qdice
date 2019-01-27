port module Board.State exposing (init, update, updateLands)

import Animation exposing (px)
import Board.PathCache exposing (createPathCache)
import Board.Types exposing (..)
import Dict
import Land
import Time exposing (millisToPosix)


init : Land.Map -> Model
init map =
    Model map Nothing Idle (createPathCache map) <| Dict.empty


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        HoverLand land ->
            ( model
            , Cmd.none
            )

        UnHoverLand land ->
            case model.hovered of
                Just l ->
                    if l == land then
                        ( { model | hovered = Nothing }
                        , Cmd.none
                        )
                    else
                        ( model
                        , Cmd.none
                        )

                Nothing ->
                    ( model
                    , Cmd.none
                    )

        ClickLand land ->
            ( model
            , Cmd.none
            )


updateLands : Model -> List LandUpdate -> Maybe BoardMove -> Model
updateLands model updates mMove =
    let
        map =
            model.map

        ( layout, _, _ ) =
            getLayout map

        landUpdates =
            List.map (updateLand layout updates) map.lands

        map_ =
            { map
                | lands = List.map Tuple.first landUpdates
            }

        move_ =
            Maybe.withDefault model.move mMove

        animations =
            List.foldl
                (\( land, diceAnimations ) ->
                    \dict ->
                        List.foldl
                            (\( index, animation ) ->
                                \dict_ ->
                                    Dict.insert (getLandDieKey land index) animation dict_
                            )
                            dict
                            diceAnimations
                )
                Dict.empty
                landUpdates
    in
        { model | map = map_, move = move_, animations = animations, hovered = Nothing }


updateLand : Land.Layout -> List LandUpdate -> Land.Land -> ( Land.Land, List ( Int, Animation.State ) )
updateLand layout updates land =
    let
        landUpdate =
            List.filter (\l -> l.emoji == land.emoji) updates
    in
        case List.head landUpdate of
            Just firstUpdate ->
                ( { land
                    | color = firstUpdate.color
                    , points = firstUpdate.points
                  }
                , if firstUpdate.color == land.color && firstUpdate.points > land.points then
                    let
                        ( cx, cy ) =
                            Land.landCenter
                                layout
                                land.cells
                    in
                        List.map
                            (\index ->
                                let
                                    yOffset =
                                        if index >= 4 then
                                            1.1
                                        else
                                            2

                                    y =
                                        cy - yOffset - (toFloat (modBy 4 index) * 1.2)
                                in
                                    ( index
                                    , Animation.interrupt
                                        [ Animation.wait <| millisToPosix <| 10 * index
                                        , Animation.toWith
                                            (Animation.easing
                                                { duration = 100
                                                , ease = \x -> x ^ 2
                                                }
                                            )
                                            [ Animation.y <| y ]
                                        ]
                                      <|
                                        Animation.style
                                            [ Animation.y <| y - (toFloat <| 10 * index) ]
                                    )
                            )
                        <|
                            List.range
                                land.points
                                firstUpdate.points
                  else
                    []
                )

            Nothing ->
                ( land, [] )
