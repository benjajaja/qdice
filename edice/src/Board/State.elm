module Board.State exposing (init, removeColor, updateLands)

import Animation exposing (px)
import Array exposing (Array)
import Board.PathCache
import Board.Types exposing (..)
import Dict
import Land exposing (Color(..), LandUpdate)


init : Land.Map -> Model
init map =
    let
        ( layout, viewBox ) =
            getLayout map

        pathCache : Dict.Dict String String
        pathCache =
            Board.PathCache.addToDict layout map.lands Dict.empty
                |> Board.PathCache.addToDictLines layout map.lands map.waterConnections
    in
    Model map Idle pathCache layout viewBox { stack = Nothing, dice = Dict.empty } Nothing


updateLands : Model -> List LandUpdate -> Maybe BoardMove -> Model
updateLands model updates mMove =
    if List.length updates == 0 then
        let
            move_ =
                Maybe.withDefault model.move mMove

            animations =
                model.animations
        in
        { model
            | animations = { animations | stack = attackAnimations model.pathCache move_ model.move }
            , move = move_
        }

    else
        let
            map =
                model.map

            landUpdates : List ( Land.Land, Array Bool )
            landUpdates =
                List.map (updateLand updates) map.lands

            lands_ =
                List.map Tuple.first landUpdates

            map_ =
                if List.length updates == 0 || lands_ == map.lands then
                    map

                else
                    { map
                        | lands = lands_
                    }

            move_ =
                Maybe.withDefault model.move mMove
        in
        { model
            | map = map_
            , move = move_
            , animations =
                { stack = attackAnimations model.pathCache move_ model.move
                , dice = giveDiceAnimations landUpdates
                }
        }


giveDiceAnimations : List ( Land.Land, Array Bool ) -> DiceAnimations
giveDiceAnimations landUpdates =
    List.foldl
        (\( land, diceAnimations ) ->
            if Array.length diceAnimations == 0 then
                identity

            else
                Dict.insert land.emoji diceAnimations
        )
        Dict.empty
        landUpdates


updateLand : List LandUpdate -> Land.Land -> ( Land.Land, Array Bool )
updateLand updates land =
    let
        match =
            List.filter (\l -> l.emoji == land.emoji) updates
    in
    case List.head match of
        Just landUpdate ->
            if
                landUpdate.color
                    /= land.color
                    || landUpdate.points
                    /= land.points
                    || landUpdate.capital
                    /= land.capital
            then
                ( { land
                    | color = landUpdate.color
                    , points = landUpdate.points
                    , capital = landUpdate.capital
                  }
                , updateLandAnimations land landUpdate
                )

            else
                ( land, Array.empty )

        Nothing ->
            ( land, Array.empty )


updateLandAnimations : Land.Land -> LandUpdate -> Array Bool
updateLandAnimations land landUpdate =
    if landUpdate.color /= Land.Neutral && landUpdate.color == land.color && landUpdate.points > land.points then
        (List.range 0 (land.points - 1)
            |> List.map (always False)
        )
            ++ (List.range
                    land.points
                    landUpdate.points
                    |> List.map (always True)
               )
            |> Array.fromList

    else
        Array.empty


attackAnimations : PathCache -> BoardMove -> BoardMove -> Maybe ( Land.Emoji, AnimationState )
attackAnimations pathCache move oldMove =
    case move of
        FromTo from to ->
            Just <| ( from.emoji, translateStack False pathCache from to )

        Idle ->
            case oldMove of
                FromTo from to ->
                    Just <| ( from.emoji, translateStack True pathCache from to )

                _ ->
                    Nothing

        _ ->
            Nothing


translateStack : Bool -> PathCache -> Land.Land -> Land.Land -> AnimationState
translateStack reverse pathCache from to =
    let
        ( fx, fy ) =
            Board.PathCache.center pathCache from.emoji
                |> Maybe.withDefault ( 0, 0 )

        ( tx, ty ) =
            Board.PathCache.center pathCache to.emoji
                |> Maybe.withDefault ( 0, 0 )

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
    Animation.interrupt
        [ Animation.toWith
            (Animation.easing
                { duration =
                    if not reverse then
                        200

                    else
                        100
                , ease = \z -> z ^ 2
                }
            )
            [ toAnimation ]
        ]
    <|
        Animation.style [ fromAnimation ]


removeColor : Model -> Color -> Model
removeColor model color =
    let
        map =
            model.map

        map_ =
            { map
                | lands =
                    List.map
                        (\land ->
                            if land.color == color then
                                { land | color = Neutral }

                            else
                                land
                        )
                        map.lands
            }
    in
    { model | map = map_ }
