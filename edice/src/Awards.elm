module Awards exposing (awardsShortList)

import Html exposing (..)
import Html.Attributes exposing (..)
import Svg exposing (svg, use)
import Svg.Attributes
import Types exposing (Award, LoggedUser, Msg(..))


awardsShortList : LoggedUser -> List (Html Msg)
awardsShortList user =
    if List.length user.awards > 0 then
        List.map awardIcon user.awards

    else
        []


awardIcon : Award -> Html Msg
awardIcon award =
    svg
        [ Svg.Attributes.viewBox "0 0 100 100"
        , Svg.Attributes.fill "currentColor"
        , Svg.Attributes.width "20"
        , Svg.Attributes.height "20"
        ]
    <|
        [ Svg.use
            [ Svg.Attributes.xlinkHref <| "assets/awards.svg#" ++ awardSvgId award
            , Svg.Attributes.fill <| awardFill award
            ]
            []
        ]
            ++ awardText award


awardFill : Award -> String
awardFill award =
    case award.type_ of
        "monthly_rank" ->
            case award.position of
                1 ->
                    "goldenrod"

                2 ->
                    "silver"

                3 ->
                    "bronze"

                _ ->
                    "darkgrey"

        _ ->
            "black"


awardSvgId : Award -> String
awardSvgId award =
    case award.type_ of
        "monthly_rank" ->
            "laurel"

        "early_adopter" ->
            "lander"

        _ ->
            ""


awardText : Award -> List (Html Msg)
awardText award =
    case award.type_ of
        "monthly_rank" ->
            [ Svg.text_
                [ Svg.Attributes.x "50%"
                , Svg.Attributes.y "50%"
                , Svg.Attributes.textAnchor "middle"
                , Svg.Attributes.alignmentBaseline "middle"
                , Svg.Attributes.fontSize "3.5em"
                ]
                [ Svg.text <| String.fromInt <| award.position
                ]
            ]

        _ ->
            []
