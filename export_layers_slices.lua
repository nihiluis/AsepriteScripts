--[[

Description: 
An Aseprite script to export all slices as .png files in groups.

Usage:
Slices are exported to .png files. The name of the files
are the name of the slices. To group different slices,
use the user data field of the slice as the group number.
You can create subgroups to save the files in nested folders
by using the path separator symbol of your operative system
(which is "/" for GNU/Linux and "\" for Windows). For example:
"group1\subgroup1\subsubgroup1" (Windows)
"group1/subgroup1/subsubgroup2" (Linux)
"group1\subgroup2"              (Windows)
"group1\subgroup2\subsubgroup2" (Windows)
"group1\subgroup2\subsubgroup2" (Windows)
If the user data field is empty, then no group is assigned
and the slice is exported to the root selected folder.

About:
Made by Gaspi. Commissioned by Imvested.
   - Web: https://gaspi.games/
   - Twitter: @_Gaspi

--]]

-- Import main.
local err = dofile("main.lua")
if err ~= 0 then return err end

-- Open main dialog.
local dlg = Dialog("Export slices by layers")
dlg:file{
    id = "directory",
    label = "Output directory:",
    filename = Sprite.filename,
    open = false
}
dlg:entry{
    id = "filename",
    label = "File name format:",
    text = "{slicedata}" .. Sep .. "{slicename}_{layername}"
}
dlg:combobox{
    id = 'group_sep',
    label = 'Group separator:',
    option = Sep,
    options = {Sep, '-', '_'}
}
dlg:combobox{
    id = 'format',
    label = 'Export Format:',
    option = 'png',
    options = {'png', 'gif', 'jpg'}
}
dlg:slider{id = 'scale', label = 'Export Scale:', min = 1, max = 10, value = 1}
dlg:check{id = "save", label = "Save sprite:", selected = false}
dlg:button{id = "ok", text = "Export"}
dlg:button{id = "cancel", text = "Cancel"}
dlg:show()

if not dlg.data.ok then return 0 end

-- Get path and filename
local output_path = Dirname(dlg.data.directory)
local filename = dlg.data.filename .. "." .. dlg.data.format

if output_path == nil then
    local dlg = MsgDialog("Error", "No output directory was specified.")
    dlg:show()
    return 1
end

filename = filename:gsub("{spritename}",
                         RemoveExtension(Basename(Sprite.filename)))

-- Save original bounds to restore later.
Sprite:resize(Sprite.width * dlg.data.scale, Sprite.height * dlg.data.scale)
local og_bounds = Sprite.bounds

-- Count how many times a slice with the same name and group exist.
local slice_count = {}
for _, slice in ipairs(Sprite.slices) do
    local slice_id = slice.data .. Sep .. slice.name
    if slice_count[slice_id] == nil then
        slice_count[slice_id] = 1
    else
        slice_count[slice_id] = slice_count[slice_id] + 1
    end
end

local n_layers = 0

local function exportLayers(sprite, root_layer, filename, group_sep, data)
    for _, layer in ipairs(root_layer.layers) do
        local filename = filename
        if layer.isGroup then
            -- Recursive for groups.
            local previousVisibility = layer.isVisible
            layer.isVisible = true
            filename = filename:gsub("{layergroups}",
                                     layer.name .. group_sep .. "{layergroups}")
            exportLayers(sprite, layer, filename, group_sep, data)
            layer.isVisible = previousVisibility
        else
            -- Individual layer. Export it.
            layer.isVisible = true
            filename = filename:gsub("{layergroups}", "")
            filename = filename:gsub("{layername}", layer.name)
            os.execute("mkdir \"" .. Dirname(filename) .. "\"")
            if data.spritesheet then
                app.command.ExportSpriteSheet{
                    ui=false,
                    askOverwrite=false,
                    type=SpriteSheetType.HORIZONTAL,
                    columns=0,
                    rows=0,
                    width=0,
                    height=0,
                    bestFit=false,
                    textureFilename=filename,
                    dataFilename="",
                    dataFormat=SpriteSheetDataFormat.JSON_HASH,
                    borderPadding=0,
                    shapePadding=0,
                    innerPadding=0,
                    trim=data.trim,
                    mergeDuplicates=data.mergeDuplicates,
                    extrude=false,
                    openGenerated=false,
                    layer="",
                    tag="",
                    splitLayers=false,
                    listLayers=layer,
                    listTags=true,
                    listSlices=true,
                }
            else
                sprite:saveCopyAs(filename)
            end
            layer.isVisible = false
            n_layers = n_layers + 1
        end
    end
end

local group_sep = dlg.data.group_sep
local output_path = Dirname(dlg.data.directory)

-- Export slices.
for _, slice in ipairs(Sprite.slices) do
    -- Keep track of the origin offset.
    og_bounds.x = og_bounds.x - slice.bounds.x
    og_bounds.y = og_bounds.y - slice.bounds.y

    -- Crop the sprite to this slice's size and position.
    Sprite:crop(slice.bounds)

    -- Save the cropped sprite.
    local slice_id = slice.data .. Sep .. slice.name
    local slice_filename = filename:gsub("{slicename}", slice.name)
    slice_filename = slice_filename:gsub("{slicedata}", slice.data)
    if slice_count[slice_id] > 1 then
        slice_filename = slice_filename .. "_" .. slice_count[slice_id]
    end

    -- Create output dir in case it doesn't exist.
    os.execute("mkdir \"" .. Dirname(output_path .. slice_filename) .. "\"")
    slice_count[slice_id] = slice_count[slice_id] - 1

    local layers_visibility_data = HideLayers(Sprite)
    exportLayers(Sprite, Sprite, output_path .. slice_filename, group_sep, dlg.data)
    RestoreLayersVisibility(Sprite, layers_visibility_data)
end

-- Restore original bounds.
Sprite:crop(og_bounds)
Sprite:resize(Sprite.width / dlg.data.scale, Sprite.height / dlg.data.scale)

-- Save the original file if specified
if dlg.data.save then Sprite:saveAs(dlg.data.directory) end

-- Success dialog.
local dlg = MsgDialog("Success!", "Exported " .. #Sprite.slices .. " slices and " .. n_layers.. " layers in total.")
dlg:show()

return 0
