port module Board.State exposing (init, update, updateLands)

import Dict
import Animation exposing (px)
import Board.Types exposing (..)
import Board.PathCache exposing (createPathCache)
import Land


init : Land.Map -> Model
init map =
    Model map Nothing Idle (createPathCache map) <| Dict.empty


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        HoverLand land ->
            { model | hovered = Just land } ! []

        UnHoverLand land ->
            case model.hovered of
                Just l ->
                    if l == land then
                        { model | hovered = Nothing } ! []
                    else
                        model ! []

                Nothing ->
                    model ! []

        ClickLand land ->
            model ! []


updateLands : Model -> List LandUpdate -> Maybe BoardMove -> Model
updateLands model update move =
    let
        map =
            model.map

        ( layout, _, _ ) =
            getLayout map

        landUpdates =
            List.map (updateLand layout update) map.lands

        map_ =
            { map
                | lands = List.map Tuple.first landUpdates
            }

        move_ =
            case move of
                Just move ->
                    move

                Nothing ->
                    model.move

        animations =
            List.foldl
                (\( land, diceAnimations ) ->
                    \dict ->
                        List.foldl
                            (\( index, animation ) ->
                                \dict ->
                                    Dict.insert (getLandDieKey land index) animation dict
                            )
                            dict
                            diceAnimations
                )
                Dict.empty
                landUpdates
    in
        { model | map = map_, move = move_, animations = animations }


updateLand : Land.Layout -> List LandUpdate -> Land.Land -> ( Land.Land, List ( Int, Animation.State ) )
updateLand layout updates land =
    let
        update =
            List.filter (\l -> l.emoji == land.emoji) updates
    in
        case List.head update of
            Just update ->
                ( { land
                    | color = update.color
                    , points = update.points
                  }
                , if update.color == land.color && update.points > land.points then
                    let
                        ( cx, cy ) =
                            (Land.landCenter
                                layout
                                land.cells
                            )
                    in
                        List.map
                            (\index ->
                                let
                                    yOffset =
                                        if index >= 4 then
                                            1.15
                                        else
                                            1.5

                                    y =
                                        cy - yOffset - (toFloat (index % 4) * 1.8)
                                in
                                    ( index
                                    , Animation.interrupt
                                        [ Animation.wait (10 * index)
                                        , Animation.toWith
                                            (Animation.easing
                                                { duration = 100
                                                , ease = (\x -> x ^ 2)
                                                }
                                            )
                                            [ Animation.y <| y ]
                                        ]
                                      <|
                                        Animation.style
                                            [ Animation.y <| y - 10 * index ]
                                    )
                            )
                        <|
                            List.range
                                land.points
                                update.points
                  else
                    []
                )

            Nothing ->
                ( land, [] )
