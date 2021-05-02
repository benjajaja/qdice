module Backend.Encoding exposing (authStateEncoder, encodeAuthNetwork, encodeClient, encodePlayerAction, loginEncoder, myProfileUpdateEncoder, passwordEncoder, profileEncoder)

import Cropper
import Game.Types exposing (PlayerAction(..), actionToString)
import Json.Encode exposing (Value, bool, encode, int, list, null, object, string)
import MyProfile.Types exposing (MyProfileUpdate)
import Types exposing (..)


stringOrNull : Maybe String -> Value
stringOrNull =
    Maybe.map string >> Maybe.withDefault null


profileEncoder : LoggedUser -> Value
profileEncoder user =
    object
        [ ( "id", string user.id )
        , ( "name", string user.name )
        , ( "email", stringOrNull user.email )
        , ( "picture", string user.picture )
        ]


encodePlayerAction : Maybe String -> String -> PlayerAction -> String
encodePlayerAction jwt clientId action =
    encode 2 <|
        object <|
            List.concat
                [ [ ( "type", string <| actionToString action ) ]
                , [ ( "client", string clientId ) ]
                , case jwt of
                    Just jwt_ ->
                        [ ( "token", string jwt_ ) ]

                    Nothing ->
                        []
                , case actionPayload action of
                    Just payload ->
                        [ ( "payload", payload ) ]

                    Nothing ->
                        []
                ]


encodeClient : String -> String -> String
encodeClient jwt clientId =
    encode 2 <|
        object <|
            [ ( "client", string clientId ), ( "token", string jwt ) ]


actionPayload : PlayerAction -> Maybe Value
actionPayload action =
    case action of
        Attack from to ->
            Just <| list string [ from, to ]

        Chat text ->
            Just <| string text

        Flag position ->
            Just <| int position

        ToggleReady ready ->
            Just <| bool ready

        _ ->
            Nothing


encodeAuthNetwork : AuthNetwork -> String
encodeAuthNetwork network =
    case network of
        Google ->
            "google"

        Github ->
            "github"

        Reddit ->
            "reddit"

        Password ->
            "password"

        Telegram ->
            "telegram"


authStateEncoder : AuthState -> Value
authStateEncoder state =
    object
        [ ( "network"
          , string <| encodeAuthNetwork state.network
          )
        , ( "table"
          , stringOrNull state.table
          )
        , ( "addTo"
          , stringOrNull state.addTo
          )
        ]


myProfileUpdateEncoder : MyProfileUpdate -> Value
myProfileUpdateEncoder update =
    object
        [ ( "name", stringOrNull update.name )
        , ( "email", stringOrNull update.email )
        , ( "picture", cropDataEncoder update.picture )
        , ( "password", stringOrNull update.password )
        , ( "passwordCheck", stringOrNull update.passwordCheck )
        ]


cropDataEncoder : Maybe Cropper.CropData -> Value
cropDataEncoder =
    Maybe.map
        (\cropData ->
            object
                [ ( "url", string cropData.url )
                , ( "size", rect cropData.size )
                , ( "crop", rect cropData.crop )
                , ( "resized", rect cropData.resized )
                , ( "origin", point cropData.origin )
                ]
         -- { url : String
         -- , size : Rect
         -- , crop : Rect
         -- , resized : Rect
         -- , origin : Point
        )
        >> Maybe.withDefault null


rect : { width : Int, height : Int } -> Value
rect { width, height } =
    object [ ( "width", int width ), ( "height", int height ) ]


point : { x : Int, y : Int } -> Value
point { x, y } =
    object [ ( "x", int x ), ( "y", int y ) ]


passwordEncoder : ( String, String ) -> Maybe String -> Value
passwordEncoder ( email, password ) passwordCheck =
    object
        [ ( "email", string email )
        , ( "password", string password )
        , ( "passwordCheck", stringOrNull passwordCheck )
        ]


loginEncoder : ( String, String ) -> Value
loginEncoder ( email, password ) =
    object
        [ ( "email", string email )
        , ( "password", string password )
        ]
