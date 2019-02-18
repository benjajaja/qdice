port module Board.State exposing (init, update, updateLands)

import Animation exposing (px)
import Board.PathCache exposing (createPathCache)
import Board.Types exposing (..)
import Board.Colors
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

        landUpdates : List ( Land.Land, List ( Int, Animation.State ) )
        landUpdates =
            List.map (updateLand layout updates) map.lands

        map_ =
            { map
                | lands = List.map Tuple.first landUpdates
            }

        move_ =
            Maybe.withDefault model.move mMove
    in
        { model
            | map = map_
            , move = move_
            , animations =
                Dict.union
                    (Dict.union (animationsDict landUpdates) <|
                        attackAnimations layout move_ model.move
                    )
                    model.animations
            , hovered = Nothing
        }


animationsDict : List ( Land.Land, List ( Int, Animation.State ) ) -> Dict.Dict String Animation.State
animationsDict landUpdates =
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
                , updateLandAnimations layout land firstUpdate
                )

            Nothing ->
                ( land, [] )


updateLandAnimations : Land.Layout -> Land.Land -> LandUpdate -> List ( Int, Animation.State )
updateLandAnimations layout land landUpdate =
    if landUpdate.color == land.color && landUpdate.points > land.points then
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
                    landUpdate.points
    else
        []


attackAnimations : Land.Layout -> BoardMove -> BoardMove -> Dict.Dict String Animation.State
attackAnimations layout move oldMove =
    case move of
        FromTo from to ->
            Dict.fromList
                [ ( "attack_" ++ from.emoji
                  , translateStack False layout from to
                  )
                , ( "attack_" ++ to.emoji
                  , translateStack False layout to from
                  )
                ]

        Idle ->
            case oldMove of
                FromTo from to ->
                    Dict.fromList
                        [ ( "attack_" ++ from.emoji
                          , translateStack True layout from to
                          )
                        , ( "attack_" ++ to.emoji
                          , translateStack True layout to from
                          )
                        ]

                _ ->
                    Dict.empty

        _ ->
            Dict.empty


translateStack reverse layout from to =
    let
        ( fx, fy ) =
            Land.landCenter
                layout
                from.cells

        ( tx, ty ) =
            Land.landCenter
                layout
                to.cells

        x =
            (tx - fx) / 3

        y =
            (ty - fy) / 3

        ( fromAnimation, toAnimation ) =
            if reverse == True then
                ( Animation.translate (Animation.px x) (Animation.px y)
                , Animation.translate (Animation.px 0) (Animation.px 0)
                )
            else
                ( Animation.translate (Animation.px 0) (Animation.px 0)
                , Animation.translate (Animation.px x) (Animation.px y)
                )
    in
        Animation.queue
            [ Animation.toWith
                (Animation.easing
                    { duration = 100
                    , ease = \z -> z ^ 2
                    }
                )
                [ toAnimation ]
            ]
        <|
            Animation.style [ fromAnimation ]
