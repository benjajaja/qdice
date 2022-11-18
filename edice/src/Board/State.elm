module Board.State exposing (init, removeColor, updateLands)

import Animation
import Array exposing (Array)
import Board.PathCache
import Board.Types exposing (..)
import Dict
import Ease
import Land exposing (Color(..), DiceSkin(..), Emoji, Land, LandDict, LandUpdate, Map)
import List exposing (length)


init : BoardOptions -> Map -> Model
init options map =
    let
        ( layout, viewBox ) =
            getLayout map

        pathCache : Dict.Dict String String
        pathCache =
            Board.PathCache.addToDict layout (Land.landsList map.lands) Dict.empty
                |> Board.PathCache.addToDictLines layout (Land.landsList map.lands) map.waterConnections
    in
    Model map options Idle pathCache layout viewBox { stack = Nothing, dice = Dict.empty } Nothing


updateLands : Model -> List LandUpdate -> Maybe BoardMove -> List (BoardPlayer a) -> Model
updateLands model updates mmove players =
    let
        map =
            model.map

        ( lands, updated ) =
            List.foldl (updateLand players) ( map.lands, [] ) updates

        map_ =
            if length updates == 0 || lands == map.lands then
                map

            else
                { map
                    | lands = lands
                }
        animations = case model.boardOptions.diceVisible of
            Animated -> 
              { stack = model.animations.stack
              , dice = giveDiceAnimations updated
              }
            _ -> model.animations
    in
    { model
        | map = map_
        , animations = animations
    }
        |> updateMove mmove


updateMove : Maybe BoardMove -> Model -> Model
updateMove mmove model =
    case mmove of
        Nothing ->
            model

        Just move ->
            let
                animations =
                    model.animations
                newAnimations =
                  case model.boardOptions.diceVisible of
                    Animated -> { animations | stack = attackAnimations model.pathCache move model.move }
                    _ -> model.animations
            in
            { model
                | animations = newAnimations
                , move = move
            }


giveDiceAnimations : List ( Land, Array Bool ) -> DiceAnimations
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


type alias AnimList =
    List ( Land, Array Bool )


type alias UpdateResult =
    ( LandDict, AnimList )


updateLand : List (BoardPlayer a) -> LandUpdate -> UpdateResult -> UpdateResult
updateLand players update ( dict, list ) =
    case Dict.get update.emoji dict of
        Nothing ->
            ( dict, list )

        Just land ->
            updateLandFound players update land ( dict, list )


updateLandFound : List (BoardPlayer a) -> LandUpdate -> Land -> UpdateResult -> UpdateResult
updateLandFound players update land ( dict, list ) =
    if
        update.color
            /= land.color
            || update.points
            /= land.points
            || update.capital
            /= land.capital
    then
        let
            newLand =
                { land
                    | color = update.color
                    , points = update.points
                    , diceSkin = skinFromColor players update.color
                    , capital = update.capital
                }

            anims =
                updateLandAnimations land update
        in
        ( Dict.insert land.emoji newLand dict, list ++ [ ( land, anims ) ] )

    else
        ( dict, list )


skinFromColor : List (BoardPlayer a) -> Color -> DiceSkin
skinFromColor players c =
    case List.head <| List.filter (\{ color } -> color == c) players of
        Just { skin } ->
            skin

        Nothing ->
            Normal


updateLandAnimations : Land -> LandUpdate -> Array Bool
updateLandAnimations land landUpdate =
    if landUpdate.color /= Neutral && landUpdate.color == land.color && landUpdate.points > land.points then
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


attackAnimations : PathCache -> BoardMove -> BoardMove -> Maybe ( Emoji, AnimationState )
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


translateStack : Bool -> PathCache -> Land -> Land -> AnimationState
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
            (Animation.easing <|
                if not reverse then
                    { duration = 400
                    , ease = Ease.outCubic
                    }

                else
                    { duration = 200
                    , ease = Ease.inCubic
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
                    Dict.map
                        (\_ ->
                            \land ->
                                if land.color == color then
                                    { land | color = Neutral, diceSkin = Normal }

                                else
                                    land
                        )
                        map.lands
            }
    in
    { model | map = map_ }
