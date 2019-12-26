module Awards exposing (awardsShortList)

import Game.Types exposing (Award)
import Html exposing (..)
import Html.Attributes exposing (..)
import Svg exposing (svg, use)
import Svg.Attributes
import Types exposing (Msg(..))


awardsShortList : Int -> List Award -> List (Html Msg)
awardsShortList size awards =
    if List.length awards > 0 then
        List.map (awardIcon size) awards

    else
        []


awardIcon : Int -> Award -> Html Msg
awardIcon size award =
    svg
        [ Svg.Attributes.viewBox "0 0 100 100"
        , Svg.Attributes.fill "currentColor"
        , Svg.Attributes.width <| String.fromInt size
        , Svg.Attributes.height <| String.fromInt size
        , Svg.Attributes.style "background:white;border-radius:50%; color: black"
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
            "#222222"


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
                , Svg.Attributes.fontSize "5em"
                ]
                [ Svg.text <| String.fromInt <| award.position
                ]
            ]

        _ ->
            []
