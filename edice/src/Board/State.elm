module Board.State exposing (init, update, updateLands)

import Animation exposing (px)
import Animation.Messenger
import Board.PathCache
import Board.Types exposing (..)
import Dict
import Land
import Time


init : Land.Map -> Model
init map =
    let
        ( layout, viewBox ) =
            getLayout map

        pathCache : Dict.Dict String String
        pathCache =
            Board.PathCache.addToDict layout map.lands Dict.empty
                |> Board.PathCache.addToDictLines layout map.lands map.extraAdjacency
    in
    Model map Nothing Idle pathCache ( layout, viewBox ) Dict.empty


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        HoverLand land ->
            -- ugly optimization for Html.lazy ref-equality check
            case model.hovered of
                Just hovered ->
                    if hovered /= land then
                        ( { model | hovered = Just land }
                        , Cmd.none
                        )

                    else
                        ( model, Cmd.none )

                Nothing ->
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


updateLands : Model -> Time.Posix -> List LandUpdate -> Maybe BoardMove -> (String -> Msg) -> Model
updateLands model posix updates mMove msg =
    if List.length updates == 0 then
        let
            ( layout, _ ) =
                model.layout

            move_ =
                Maybe.withDefault model.move mMove
        in
        { model
            | animations =
                -- new move replaces any older animations
                attackAnimations layout move_ model.move msg
            , move = move_
        }

    else
        let
            map =
                model.map

            ( layout, _ ) =
                model.layout

            landUpdates : List ( Land.Land, List ( Int, AnimationState ) )
            landUpdates =
                List.map (updateLand posix updates) map.lands

            map_ =
                { map
                    | lands =
                        if List.length landUpdates == 0 then
                            map.lands

                        else
                            List.map Tuple.first landUpdates
                }

            move_ =
                Maybe.withDefault model.move mMove

            giveDiceAnimations =
                animationsDict landUpdates

            attackAnimations_ =
                attackAnimations layout move_ model.move msg
        in
        { model
            | map = map_
            , move = move_
            , animations =
                Dict.union giveDiceAnimations attackAnimations_
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


updateLand : Time.Posix -> List LandUpdate -> Land.Land -> ( Land.Land, List ( Int, AnimationState ) )
updateLand posix updates land =
    let
        match =
            List.filter (\l -> l.emoji == land.emoji) updates
    in
    case List.head match of
        Just landUpdate ->
            if landUpdate.color /= land.color || landUpdate.points /= land.points then
                ( { land
                    | color = landUpdate.color
                    , points = landUpdate.points
                  }
                , updateLandAnimations posix land landUpdate
                )

            else
                ( land, [] )

        Nothing ->
            ( land, [] )


updateLandAnimations : Time.Posix -> Land.Land -> LandUpdate -> List ( Int, AnimationState )
updateLandAnimations posix land landUpdate =
    if landUpdate.color /= Land.Neutral && landUpdate.color == land.color && landUpdate.points > land.points then
        List.map
            (\index ->
                ( index
                , CssAnimation posix
                )
            )
        <|
            List.range
                land.points
                landUpdate.points

    else
        []


attackAnimations : Land.MapSize -> BoardMove -> BoardMove -> (String -> Msg) -> Animations
attackAnimations layout move oldMove msg =
    case move of
        FromTo from to ->
            Dict.fromList
                [ ( "attack_" ++ from.emoji
                  , translateStack False layout from to <| msg <| "attack_" ++ from.emoji
                  )
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


translateStack : Bool -> Land.MapSize -> Land.Land -> Land.Land -> Msg -> AnimationState
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
    Animation <|
        Animation.queue
            (Animation.toWith
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
                :: (if reverse == True then
                        [ Animation.Messenger.send doneMsg ]

                    else
                        []
                   )
            )
        <|
            Animation.style [ fromAnimation ]
