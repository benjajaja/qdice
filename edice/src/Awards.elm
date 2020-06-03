module Awards exposing (awardsShortList)

import Game.Types exposing (Award)
import Html exposing (..)
import Html.Attributes exposing (..)
import Ordinal exposing (ordinal)
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

        -- , Svg.Attributes.style "background:white;border-radius:50%; color: black"
        ]
    <|
        [ Svg.use
            [ Svg.Attributes.xlinkHref <| "assets/awards.svg#" ++ awardSvgId award
            , Svg.Attributes.fill <| awardFill award
            ]
            [ awardTitleElement award
            ]
        ]
            ++ awardText award


awardTitleElement : Award -> Html msg
awardTitleElement award =
    Svg.title [] [ Svg.text <| awardTitle award ]


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
                    "coral"

                _ ->
                    "darkgrey"

        "weekly_rank" ->
            case award.position of
                1 ->
                    "gold"

                2 ->
                    "silver"

                3 ->
                    "coral"

                _ ->
                    "darkgrey"

        _ ->
            "#222222"


awardSvgId : Award -> String
awardSvgId award =
    case award.type_ of
        "monthly_rank" ->
            "monthly"

        "weekly_rank" ->
            "weekly_" ++ Maybe.withDefault "Planeta" award.table

        "early_adopter" ->
            "early"

        _ ->
            ""


awardText : Award -> List (Html Msg)
awardText award =
    case award.type_ of
        "monthly_rank" ->
            [ Svg.text_
                [ Svg.Attributes.x "50%"
                , Svg.Attributes.y "60%"
                , Svg.Attributes.textAnchor "middle"
                , Svg.Attributes.dominantBaseline "middle"
                , Svg.Attributes.fontSize "4em"
                ]
                [ awardTitleElement award
                , Svg.text <| String.fromInt <| award.position
                ]
            ]

        _ ->
            []


awardTitle : Award -> String
awardTitle award =
    case award.type_ of
        "early_adopter" ->
            "Early Adopter 💝"

        "monthly_rank" ->
            "Monthly rank: " ++ ordinal award.position ++ " @ " ++ String.slice 0 10 award.timestamp

        "weekly_rank" ->
            "Weekly rank"
                ++ (case award.table of
                        Just table ->
                            " on table " ++ table

                        Nothing ->
                            ""
                   )
                ++ ": "
                ++ ordinal award.position
                ++ " @ "
                ++ String.slice 0 10 award.timestamp

        _ ->
            "Unknown award"
