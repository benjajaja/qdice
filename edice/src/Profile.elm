module Profile exposing (view)

import Awards
import Helpers exposing (dataTestId, pointsSymbol, pointsToNextLevel)
import Html exposing (..)
import Html.Attributes exposing (..)
import Ordinal exposing (ordinal)
import Types exposing (..)


view : Model -> UserId -> String -> Html Msg
view model id name =
    div [ class "" ]
        [ div [ class "edPlayerBox__inner" ] <|
            playerBox <|
                Maybe.withDefault
                    { id = "0"
                    , name = name
                    , points = 0
                    , rank = 0
                    , level = 0
                    , levelPoints = 0
                    , awards = []
                    , picture = "assets/empty_profile_picture.svg"
                    }
                    model.otherProfile
        ]


playerBox : Profile -> List (Html Msg)
playerBox user =
    [ div [ class "edPlayerBox__Name" ]
        [ text user.name
        ]
    , div [ class "edPlayerBox__stat" ] [ text "Level: ", text <| String.fromInt user.level ++ "▲" ]
    , if List.length user.awards > 0 then
        div [ class "edPlayerBox__awards" ] <| Awards.awardsShortList 20 user.awards

      else
        text ""
    , div [ class "edPlayerBox__stat" ] [ text "Points: ", text <| String.fromInt user.points ++ pointsSymbol ]
    , div [ class "edPlayerBox__stat" ]
        [ text <| (String.fromInt <| pointsToNextLevel user.level user.levelPoints) ++ pointsSymbol
        , text " points to next level"
        ]
    , div [ class "edPlayerBox__stat" ] [ text "Monthly rank: ", text <| ordinal user.rank ]
    ]



-- div [] [
-- div [] [
-- model.otherProfile
-- |> Maybe.map .name
-- |> Maybe.withDefault name
-- |> text
