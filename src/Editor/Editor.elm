port module Editor.Editor exposing (..)

import Html
import Html.Attributes
import Html.Events
import Material
import Material.Button as Button
import Material.Options as Options
import Material.Icon as Icon
import Editor.Types exposing (Msg(..), Model)
import Types
import Board
import Board.Types exposing (Msg(..))
import Land
import Maps


port selectAll : String -> Cmd msg


init : ( Model, Cmd Editor.Types.Msg )
init =
    let
        board =
            Board.init (Land.fullCellMap 20 20 Land.Editor)
    in
        ( (Model Material.model board [] [ [] ]), Cmd.none )


update : Editor.Types.Msg -> Model -> ( Model, Cmd Editor.Types.Msg )
update msg model =
    case msg of
        Mdl msg ->
            Material.update Mdl msg model

        BoardMsg boardMsg ->
            let
                ( board, boardCmd ) =
                    Board.update boardMsg model.board

                newModel =
                    case boardMsg of
                        ClickLand land ->
                            let
                                selectedLands =
                                    land :: model.selectedLands

                                map =
                                    (Land.landColor model.board.map land Land.EditorSelected
                                        |> Land.highlight False
                                    )
                                    <|
                                        land

                                -- mobile does mousedown on click, but not mouseup; quick & dirty fix
                            in
                                { model
                                    | selectedLands = selectedLands
                                    , board = { board | map = map }
                                }

                        _ ->
                            { model | board = board }
            in
                ( newModel, Cmd.map BoardMsg boardCmd )

        ClickAdd ->
            addSelectedLand model

        RandomLandColor land color ->
            Land.setColor model.board.map land color |> updateMap model Cmd.none

        ClickOutput id ->
            ( model, selectAll id )


view : Types.Model -> Html.Html Types.Msg
view model =
    let
        board =
            Board.view model.editor.board
                |> Html.map BoardMsg
    in
        Html.div []
            [ Html.div [] [ Html.text "Editor mode" ]
            , board
            , Button.render
                Editor.Types.Mdl
                [ 0 ]
                model.mdl
                [ Button.fab
                , Button.colored
                , Button.ripple
                , Options.onClick ClickAdd
                ]
                [ Icon.i "add" ]
            , Html.pre [ Html.Attributes.id "emoji-map", Html.Events.onClick <| ClickOutput "emoji-map" ] (renderSave model.editor.mapSave)
            ]
            |> Html.map Types.EditorMsg


renderSave : List (List String) -> List (Html.Html Editor.Types.Msg)
renderSave save =
    List.indexedMap
        (\row ->
            \line ->
                Html.div []
                    (List.indexedMap
                        (\col ->
                            \char ->
                                Html.div
                                    [ Html.Attributes.style
                                        [ ( "display", "inline-block" )
                                        , ( "width"
                                          , if row % 2 == 1 && col == 0 then
                                                "10px"
                                            else
                                                "20px"
                                          )
                                        ]
                                    ]
                                    [ Html.text char ]
                        )
                        line
                    )
        )
        save


addSelectedLand : Model -> ( Model, Cmd Editor.Types.Msg )
addSelectedLand model =
    case model.selectedLands of
        [] ->
            ( model, Cmd.none )

        _ ->
            let
                { board } =
                    model

                map =
                    board.map

                selectedCells =
                    List.map (\l -> l.cells) model.selectedLands
                        |> List.concat

                filterSelection lands =
                    List.filter (\l -> not <| containsAny l.cells selectedCells) lands

                newLand =
                    Land.Land selectedCells Land.Editor "🍋" False
            in
                updateMap
                    { model | selectedLands = [] }
                    (RandomLandColor
                        newLand
                        |> Land.randomPlayerColor
                    )
                    { map | lands = newLand :: (filterSelection map.lands) }


updateMap : Model -> Cmd Editor.Types.Msg -> Land.Map -> ( Model, Cmd Editor.Types.Msg )
updateMap model cmd map =
    let
        { board } =
            model

        newModel =
            { model | board = { board | map = map } }

        debugCmd =
            Maps.consoleLogMap map
    in
        ( { newModel | mapSave = Maps.toCharList map }, Cmd.batch [ cmd, debugCmd ] )


containsAny : List a -> List a -> Bool
containsAny a b =
    List.any (\a -> List.member a b) a
