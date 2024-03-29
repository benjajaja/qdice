port module Helpers exposing (Synched, combine, consoleDebug, dataTestId, dataTestValue, emptyList, find, findIndex, flip, formatPoints, httpErrorToString, indexOf, isStatus, join, last, notification, notificationClick, pipeUpdates, pointsSymbol, pointsToNextLevel, pushNotification, resultCombine, timeRandomDice, timeUnits, toDie, toDiesEmojis, triple, tupleApply, tupleCombine)

import Html exposing (Attribute)
import Html.Attributes exposing (attribute)
import Http exposing (Error(..))
import Time exposing (Posix)


port consoleDebug : String -> Cmd msg

port notification : Maybe String -> Cmd msg


port notificationClick : (String -> msg) -> Sub msg


port pushNotification : (String -> msg) -> Sub msg


type alias Synched a =
    { server : a
    , client : a
    }


pointsSymbol : String
pointsSymbol =
    "✪"


formatPoints : Int -> String
formatPoints int =
    String.fromInt int ++ pointsSymbol


findIndex : (a -> Bool) -> List a -> Int
findIndex f lst =
    findIndex_ lst f 0


findIndex_ : List a -> (a -> Bool) -> Int -> Int
findIndex_ lst f offset =
    case lst of
        [] ->
            -1

        x :: xs ->
            if f x then
                offset

            else
                findIndex_ xs f (offset + 1)


indexOf : a -> List a -> Int
indexOf a =
    findIndex <| (==) a


find : (a -> Bool) -> List a -> Maybe a
find f lst =
    List.filter f lst |> List.head


last : List a -> Maybe a
last list =
    List.drop (List.length list - 1) list
        |> List.head


pipeUpdates : (model -> b -> ( model, Cmd c )) -> b -> ( model, Cmd c ) -> ( model, Cmd c )
pipeUpdates updater arg ( model, cmd ) =
    let
        ( model_, cmd_ ) =
            updater model arg
    in
    ( model_, Cmd.batch [ cmd, cmd_ ] )


httpErrorToString : Http.Error -> String
httpErrorToString err =
    case err of
        NetworkError ->
            "No connection"

        BadStatus status ->
            "Server/Client error: HTTP " ++ String.fromInt status

        BadUrl url ->
            "Bad URL error: " ++ url

        Timeout ->
            "Networked timed out"

        BadBody error ->
            "Server/Client error: " ++ error


isStatus : Int -> Http.Error -> Bool
isStatus code err =
    case err of
        BadStatus status ->
            status == code

        _ ->
            False

dataTestId : String -> Attribute msg
dataTestId id =
    attribute "data-test-id" id


dataTestValue : String -> String -> Attribute msg
dataTestValue key value =
    attribute ("data-test-" ++ key) value


pointsToNextLevel : Int -> Int -> Int
pointsToNextLevel level points =
    (((toFloat level + 1 + 10) ^ 3) * 0.1 |> ceiling) - points


triple : a -> b -> c -> ( a, b, c )
triple a b c =
    ( a, b, c )



{- From https://package.elm-lang.org/packages/elm-community/maybe-extra/latest -}


combine : List (Maybe a) -> Maybe (List a)
combine =
    List.foldr (Maybe.map2 (::)) (Just [])


resultCombine : List (Result s a) -> Result s (List a)
resultCombine =
    List.foldr (Result.map2 (::)) (Ok [])


tupleCombine : ( Maybe a, Maybe b ) -> Maybe ( a, b )
tupleCombine ( ma, mb ) =
    Maybe.andThen (\a -> Maybe.andThen (Tuple.pair a >> Just) mb) ma


tupleApply : (a -> b -> c) -> ( a, b ) -> c
tupleApply fn ( a, b ) =
    fn a b


timeUnits : Int -> ( Int, String )
timeUnits seconds =
    if seconds < 60 then
        ( seconds, "second" )

    else if seconds < 60 * 60 then
        ( round <| toFloat seconds / 60, "minute" )

    else if seconds < 60 * 60 * 60 then
        ( round <| toFloat seconds / (60 * 60), "hour" )

    else if seconds < 60 * 60 * 60 * 24 then
        ( round <| toFloat seconds / (60 * 60 * 24), "day" )

    else
        ( seconds, "second" )


flip : (a -> b -> c) -> (b -> a -> c)
flip fn =
    \b a -> fn a b


emptyList : List a
emptyList =
    []


join : a -> List a -> List a
join separator list =
    List.foldl
        (\a list_ ->
            case list_ of
                [] ->
                    [ a ]

                _ ->
                    list_ ++ [ separator, a ]
        )
        []
        list


toDiesEmojis : List Int -> String
toDiesEmojis list =
    List.foldl (++) "" <| List.map toDie list


toDie : Int -> String
toDie face =
    case face of
        1 ->
            "⚀"

        2 ->
            "⚁"

        3 ->
            "⚂"

        4 ->
            "⚃"

        5 ->
            "⚄"

        6 ->
            "⚅"

        _ ->
            "🎲"


timeRandomDice : Posix -> List Int -> List Int
timeRandomDice time dice =
    List.indexedMap
        (\i _ ->
            remainderBy 6
                (round
                    (toFloat (Time.posixToMillis time)
                        / toFloat (i + 1)
                    )
                )
                + 1
        )
        dice
