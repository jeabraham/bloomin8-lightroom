local LrDialogs = import 'LrDialogs'
local LrErrors = import 'LrErrors'
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
local LrView = import 'LrView'

local bind = LrView.bind

local PublishServiceProvider = {}
local SLIDESHOW_HELPER_NAME = 'bloomin8-gallery-slideshow.sh'

PublishServiceProvider.supportsIncrementalPublish = 'only'

PublishServiceProvider.small_icon = 'small_icon.png'

PublishServiceProvider.exportPresetFields = {
    { key = 'bloomin8LocalDirectory', default = '' },
    { key = 'bloomin8DeviceHost',     default = '' },
    { key = 'bloomin8GalleryName',    default = '' },
    { key = 'bloomin8Duration',       default = '120' },
    { key = 'bloomin8RandomOrder',    default = false },
}

function PublishServiceProvider.startDialog(propertyTable)
    propertyTable.bloomin8LocalDirectory = propertyTable.bloomin8LocalDirectory or ''
    propertyTable.bloomin8DeviceHost     = propertyTable.bloomin8DeviceHost     or ''
    propertyTable.bloomin8GalleryName    = propertyTable.bloomin8GalleryName    or ''
    propertyTable.bloomin8Duration       = propertyTable.bloomin8Duration       or '120'
    if propertyTable.bloomin8RandomOrder == nil then
        propertyTable.bloomin8RandomOrder = false
    end

    propertyTable.LR_format = 'JPEG'
    propertyTable.LR_jpeg_quality = propertyTable.LR_jpeg_quality or 0.85
    propertyTable.LR_size_doConstrain = true
    propertyTable.LR_size_resizeType = 'wh'
    propertyTable.LR_size_maxWidth = 1600
    propertyTable.LR_size_maxHeight = 1200
    propertyTable.LR_size_units = 'pixels'
end

function PublishServiceProvider.sectionsForTopOfDialog(f, propertyTable)
    return {
        {
            title = 'Bloomin8 Publish (Step 1: Local Directory)',
            synopsis = bind 'bloomin8LocalDirectory',

            f:row {
                spacing = f:control_spacing(),
                f:static_text {
                    title = 'Local publish directory:',
                    alignment = 'right',
                    width = 160,
                },
                f:edit_field {
                    value = bind 'bloomin8LocalDirectory',
                    immediate = true,
                    width_in_chars = 45,
                },
            },
            f:static_text {
                title = 'Files are rendered as JPEG, fit within 1600×1200px (Width & Height).',
                fill_horizontal = 1,
            },
        },
        {
            title = 'Bloomin8 Publish (Step 2: Device Upload & Slideshow)',
            synopsis = bind 'bloomin8DeviceHost',

            f:row {
                spacing = f:control_spacing(),
                f:static_text {
                    title = 'Device host:',
                    alignment = 'right',
                    width = 160,
                },
                f:edit_field {
                    value = bind 'bloomin8DeviceHost',
                    immediate = true,
                    width_in_chars = 30,
                },
            },
            f:static_text {
                title = 'IP address or hostname of the Bloomin8 frame. Leave blank to skip upload.',
                fill_horizontal = 1,
            },

            f:row {
                spacing = f:control_spacing(),
                f:static_text {
                    title = 'Gallery name:',
                    alignment = 'right',
                    width = 160,
                },
                f:edit_field {
                    value = bind 'bloomin8GalleryName',
                    immediate = true,
                    width_in_chars = 30,
                },
            },
            f:static_text {
                title = 'Gallery name on the device. Defaults to the local publish directory name.',
                fill_horizontal = 1,
            },

            f:row {
                spacing = f:control_spacing(),
                f:static_text {
                    title = 'Duration (seconds):',
                    alignment = 'right',
                    width = 160,
                },
                f:edit_field {
                    value = bind 'bloomin8Duration',
                    immediate = true,
                    width_in_chars = 10,
                },
            },
            f:static_text {
                title = 'Seconds between pictures in the slideshow.',
                fill_horizontal = 1,
            },

            f:row {
                spacing = f:control_spacing(),
                f:static_text {
                    title = 'Playback order:',
                    alignment = 'right',
                    width = 160,
                },
                f:popup_menu {
                    value = bind 'bloomin8RandomOrder',
                    items = {
                        { title = 'Sequential', value = false },
                        { title = 'Random',     value = true  },
                    },
                },
            },
        },
    }
end

local function ensureDirectory(path)
    if path == nil or path == '' then
        return false, 'A local publish directory is required.'
    end

    if LrFileUtils.exists(path) == 'directory' then
        return true
    end

    local created = LrFileUtils.createAllDirectories(path)
    if not created then
        return false, string.format('Failed to create publish directory: %s', path)
    end

    return true
end

local function copySlideshowHelper(destinationDirectory)
    local helperSourcePath = LrPathUtils.child(_PLUGIN.path, SLIDESHOW_HELPER_NAME)
    local helperDestinationPath = LrPathUtils.child(destinationDirectory, SLIDESHOW_HELPER_NAME)

    if LrFileUtils.exists(helperSourcePath) ~= 'file' then
        return false, string.format('Missing slideshow helper script in plugin bundle: %s', helperSourcePath)
    end

    if LrFileUtils.exists(helperDestinationPath) == 'file' then
        LrFileUtils.delete(helperDestinationPath)
    end

    local copied = LrFileUtils.copy(helperSourcePath, helperDestinationPath)
    if not copied then
        return false, string.format('Failed copying slideshow helper from %s to %s', helperSourcePath, helperDestinationPath)
    end

    return true
end

function PublishServiceProvider.processRenderedPhotos(functionContext, exportContext)
    local exportSession = exportContext.exportSession
    local exportSettings = assert(exportContext.propertyTable)
    local destinationDirectory = exportSettings.bloomin8LocalDirectory

    local ok, err = ensureDirectory(destinationDirectory)
    if not ok then
        LrDialogs.message('Bloomin8 Publish Service', err, 'critical')
        LrErrors.throwUserError(err)
    end

    ok, err = copySlideshowHelper(destinationDirectory)
    if not ok then
        LrDialogs.message('Bloomin8 Publish Service', err, 'critical')
        LrErrors.throwUserError(err)
    end

    for _, rendition in exportSession:renditions { stopIfCanceled = true } do
        local success, pathOrMessage = rendition:waitForRender()

        if not success then
            if rendition.uploadFailed then
                rendition:uploadFailed(pathOrMessage)
            end
        else
            local outputFilename = LrPathUtils.leafName(pathOrMessage)
            local destinationPath = LrPathUtils.child(destinationDirectory, outputFilename)
            local copied = LrFileUtils.copy(pathOrMessage, destinationPath)

            if copied then
                if rendition.uploadSucceeded then
                    rendition:uploadSucceeded(destinationPath)
                end
            else
                if rendition.uploadFailed then
                    rendition:uploadFailed(string.format('Failed copying %s to %s', pathOrMessage, destinationPath))
                end
            end
        end
    end

    local deviceHost = exportSettings.bloomin8DeviceHost or ''
    if deviceHost ~= '' then
        local helperPath   = LrPathUtils.child(destinationDirectory, SLIDESHOW_HELPER_NAME)
        local galleryName  = exportSettings.bloomin8GalleryName or ''
        local duration     = exportSettings.bloomin8Duration or '120'
        local randomOrder  = exportSettings.bloomin8RandomOrder

        local cmd = string.format(
            'bash %q --host %q --image-dir %q --duration %q',
            helperPath, deviceHost, destinationDirectory, duration
        )

        if galleryName ~= '' then
            cmd = cmd .. string.format(' --gallery %q', galleryName)
        end

        if randomOrder then
            cmd = cmd .. ' --random'
        end

        local exitCode = os.execute(cmd)
        if exitCode ~= 0 then
            local msg = string.format(
                'Slideshow upload finished with errors (exit code %s).\nCheck the Lightroom log for details.',
                tostring(exitCode)
            )
            LrDialogs.message('Bloomin8 Publish Service', msg, 'warning')
        end
    end
end

return PublishServiceProvider
