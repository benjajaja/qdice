port module Helpers exposing (Synched, consoleDebug, dataTestId, dataTestValue, find, findIndex, findIndex_, httpErrorResponse, httpErrorToString, indexOf, notification, pipeUpdates, playSound)

import Html exposing (Attribute)
import Html.Attributes exposing (attribute)
import Http exposing (Error(..))


port consoleDebug : String -> Cmd msg


port playSound : String -> Cmd msg


port notification : Maybe String -> Cmd msg


type alias Synched a =
    { server : a
    , client : a
    }


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


pipeUpdates : (a -> b -> ( a, Cmd c )) -> b -> ( a, Cmd c ) -> ( a, Cmd c )
pipeUpdates updater arg ( model, cmd ) =
    let
        ( model_, cmd_ ) =
            updater model arg
    in
    ( model_, Cmd.batch [ cmd, cmd_ ] )


httpErrorToString : Http.Error -> String
httpErrorToString err =
    case err of
        Http.NetworkError ->
            "No connection"

        Http.BadStatus response ->
            "Server/Client Error: " ++ response.body

        BadUrl url ->
            "URL error: " ++ url

        Timeout ->
            "Networked timed out"

        BadPayload str _ ->
            "Payload error: " ++ str


httpErrorResponse : Http.Error -> String
httpErrorResponse err =
    case err of
        Http.NetworkError ->
            "No connection"

        Http.BadStatus response ->
            response.body

        _ ->
            "HTTP Error"


dataTestId : String -> Attribute msg
dataTestId id =
    attribute "data-test-id" id


dataTestValue : String -> String -> Attribute msg
dataTestValue key value =
    attribute ("data-test-" ++ key) value
