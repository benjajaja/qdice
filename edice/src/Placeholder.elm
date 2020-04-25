module Placeholder exposing (Placeheld(..), isFetched, toFetching, toMaybe, toResult, updateIfPlaceholder, value)

{-| Placeholder type
-}


type Placeheld a
    = Placeholder a
    | Fetching a
    | Fetched a
    | Error String a


{-| Get placeholder or real value
-}
value : Placeheld a -> a
value placeholder =
    case placeholder of
        Placeholder a ->
            a

        Fetching a ->
            a

        Fetched a ->
            a

        Error _ a ->
            a


toFetching : Placeheld a -> Placeheld a
toFetching placeholder =
    Fetching <| value placeholder


{-| Result with any placeholder value
-}
toResult : Placeheld a -> Result String a
toResult placeheld =
    case placeheld of
        Placeholder a ->
            Ok a

        Fetching a ->
            Ok a

        Fetched a ->
            Ok a

        Error err a ->
            Err err


{-| Maybe only if Fetched
-}
toMaybe : Placeheld a -> Maybe a
toMaybe placeholder =
    case placeholder of
        Fetched a ->
            Just a

        _ ->
            Nothing


updateIfPlaceholder : (a -> a) -> Placeheld a -> Placeheld a
updateIfPlaceholder fn placeholder =
    case placeholder of
        Placeholder a ->
            Placeholder <| fn a

        Fetching a ->
            Fetching <| fn a

        _ ->
            placeholder


isFetched : Placeheld a -> Bool
isFetched placeholder =
    case placeholder of
        Fetched _ ->
            True

        _ ->
            False
