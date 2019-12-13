module Board.State exposing (init, update, updateLands)

import Animation exposing (px)
import Animation.Messenger
import Board.PathCache
import Board.Types exposing (..)
import Dict
import Land
import Time exposing (millisToPosix)


init : Land.Map -> Model
init map =
    let
        ( layout, w, h ) =
            getLayout map

        pathCache : Dict.Dict String String
        pathCache =
            Board.PathCache.addToDict Dict.empty layout map.lands
    in
    Model map Nothing Idle pathCache ( layout, w, h ) Dict.empty


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        HoverLand land ->
            ( { model | hovered = Just land }
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

        ClickLand _ ->
            ( model
            , Cmd.none
            )

        AnimationDone id ->
            let
                animations_ =
                    Dict.remove id model.animations
            in
            ( { model | animations = animations_ }
            , Cmd.none
            )


updateLands : Model -> List LandUpdate -> Maybe BoardMove -> (String -> Msg) -> Model
updateLands model updates mMove msg =
    let
        map =
            model.map

        ( layout, _, _ ) =
            model.layout

        landUpdates : List ( Land.Land, List ( Int, AnimationState ) )
        landUpdates =
            List.map (updateLand layout updates) map.lands

        map_ =
            { map
                | lands =
                    if List.length landUpdates == 0 then
                        map.lands

                    else
                        let
                            _ =
                                Debug.log "actually" "updating lands"
                        in
                        List.map Tuple.first landUpdates
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
                    attackAnimations layout move_ model.move msg
                )
                model.animations

        -- , hovered = Nothing
    }


animationsDict : List ( Land.Land, List ( Int, AnimationState ) ) -> Animations
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


updateLand : Land.Layout -> List LandUpdate -> Land.Land -> ( Land.Land, List ( Int, AnimationState ) )
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


updateLandAnimations : Land.Layout -> Land.Land -> LandUpdate -> List ( Int, AnimationState )
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
                        1
                            + (if index >= 4 then
                                1.1

                               else
                                2
                              )

                    y =
                        cy - yOffset - (toFloat (modBy 6 index) * 1.2)
                in
                ( index
                , Animation.queue
                    [ Animation.wait <| millisToPosix <| 2 * index
                    , Animation.toWith
                        (Animation.easing
                            { duration = 100
                            , ease = \x -> x ^ 0.5
                            }
                        )
                        [ Animation.y <| y ]
                    , Animation.Messenger.send <| AnimationDone <| getLandDieKey land index
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


attackAnimations : Land.Layout -> BoardMove -> BoardMove -> (String -> Msg) -> Animations
attackAnimations layout move oldMove msg =
    case move of
        FromTo from to ->
            Dict.fromList
                [ ( "attack_" ++ from.emoji
                  , translateStack False layout from to <| msg <| "attack_" ++ from.emoji
                  )

                -- , ( "attack_" ++ to.emoji
                -- , translateStack False layout to from
                -- )
                ]

        Idle ->
            case oldMove of
                FromTo from to ->
                    Dict.fromList
                        [ ( "attack_" ++ from.emoji
                          , translateStack True layout from to <| msg <| "attack_" ++ from.emoji
                          )

                        -- , ( "attack_" ++ to.emoji
                        -- , translateStack True layout to from
                        -- )
                        ]

                _ ->
                    Dict.empty

        _ ->
            Dict.empty


translateStack : Bool -> Land.Layout -> Land.Land -> Land.Land -> Msg -> AnimationState
translateStack reverse layout from to doneMsg =
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
            (tx - fx) * 0.75

        y =
            (ty - fy) * 0.75

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
        ([ Animation.toWith
            (Animation.easing
                { duration =
                    if not reverse then
                        100

                    else
                        100
                , ease = \z -> z ^ 2
                }
            )
            [ toAnimation ]
         ]
            ++ (if reverse == True then
                    [ Animation.Messenger.send doneMsg ]

                else
                    []
               )
        )
    <|
        Animation.style [ fromAnimation ]
