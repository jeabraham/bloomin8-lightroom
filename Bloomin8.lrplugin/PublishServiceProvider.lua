local LrDialogs = import 'LrDialogs'
local LrErrors = import 'LrErrors'
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
local LrView = import 'LrView'

local bind = LrView.bind

local PublishServiceProvider = {}
local SLIDESHOW_HELPER_NAME = 'bloomin8-gallery-slideshow.sh'
local SLIDESHOW_WRAPPER_NAME = 'bloomin8-run-slideshow.sh'
local LIGHTROOM_LOG_HINT_INLINE = 'If upload fails, check Lightroom logs: macOS ~/Library/Application Support/Adobe/Lightroom/lrc_console.log ; Windows %AppData%\\Adobe\\Lightroom\\Logs\\'
local LIGHTROOM_LOG_HINT_MULTILINE = 'Lightroom logs:\n  macOS: ~/Library/Application Support/Adobe/Lightroom/lrc_console.log\n  Windows: %AppData%\\Adobe\\Lightroom\\Logs\\'

PublishServiceProvider.supportsIncrementalPublish = 'only'

PublishServiceProvider.small_icon = 'small_icon.png'

-- Service-level settings: base directory and device host only.
-- Gallery name, duration, playback order, and orientation are per-collection.
PublishServiceProvider.exportPresetFields = {
    { key = 'bloomin8LocalDirectory', default = '' },
    { key = 'bloomin8DeviceHost',     default = '' },
}

function PublishServiceProvider.startDialog(propertyTable)
    propertyTable.bloomin8LocalDirectory = propertyTable.bloomin8LocalDirectory or ''
    propertyTable.bloomin8DeviceHost     = propertyTable.bloomin8DeviceHost     or ''

    propertyTable.LR_format = 'JPEG'
    propertyTable.LR_jpeg_quality = propertyTable.LR_jpeg_quality or 0.85
    propertyTable.LR_size_doConstrain = true
    propertyTable.LR_size_resizeType = 'dimensions'
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
                title = 'Files are rendered as JPEG, fit within 1600×1200px (Width & Height). Each collection is exported into a subdirectory named after its gallery.',
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
            f:static_text {
                title = 'Gallery name, duration, playback order, and frame orientation are configured per-collection (right-click a collection → Edit Collection Settings).',
                fill_horizontal = 1,
            },
            f:static_text {
                title = LIGHTROOM_LOG_HINT_INLINE,
                fill_horizontal = 1,
            },
        },
    }
end

-- Per-collection settings: gallery name, duration, playback order, frame orientation.
function PublishServiceProvider.viewForCollectionSettings(f, publishSettings, info)
    local collectionSettings = assert(info.collectionSettings)

    if collectionSettings.bloomin8GalleryName == nil then
        collectionSettings.bloomin8GalleryName = ''
    end
    if collectionSettings.bloomin8Duration == nil then
        collectionSettings.bloomin8Duration = '120'
    end
    if collectionSettings.bloomin8RandomOrder == nil then
        collectionSettings.bloomin8RandomOrder = false
    end
    if collectionSettings.bloomin8Orientation == nil or collectionSettings.bloomin8Orientation == '' then
        collectionSettings.bloomin8Orientation = 'portrait'
    end

    return f:view {
        f:group_box {
            title = 'Bloomin8 Collection Settings',
            fill_horizontal = 1,

            f:row {
                spacing = f:control_spacing(),
                f:static_text {
                    title = 'Gallery name:',
                    alignment = 'right',
                    width = 160,
                },
                f:edit_field {
                    value = bind { key = 'bloomin8GalleryName', object = collectionSettings },
                    immediate = true,
                    width_in_chars = 30,
                },
            },
            f:static_text {
                title = 'Gallery name on the device and name of the export subdirectory. Leave blank to use the collection name.',
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
                    value = bind { key = 'bloomin8Duration', object = collectionSettings },
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
                    value = bind { key = 'bloomin8RandomOrder', object = collectionSettings },
                    items = {
                        { title = 'Sequential', value = false },
                        { title = 'Random',     value = true  },
                    },
                },
            },

            f:row {
                spacing = f:control_spacing(),
                f:static_text {
                    title = 'Frame orientation:',
                    alignment = 'right',
                    width = 160,
                },
                f:popup_menu {
                    value = bind { key = 'bloomin8Orientation', object = collectionSettings },
                    items = {
                        { title = 'Portrait',  value = 'portrait'  },
                        { title = 'Landscape', value = 'landscape' },
                    },
                },
            },
            f:static_text {
                title = 'Set to match how your frame is physically hung on the wall.',
                fill_horizontal = 1,
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

local function copyFileReplacingExisting(sourcePath, destinationPath)
    local tempPath = string.format('%s.bloomin8-tmp', destinationPath)
    if LrFileUtils.exists(tempPath) == 'file' then
        local deleted = LrFileUtils.delete(tempPath)
        if not deleted then
            return false, string.format('Failed removing temporary file at %s', tempPath)
        end
    end

    local copied = LrFileUtils.copy(sourcePath, tempPath)
    if not copied then
        return false, string.format('Failed copying %s to temporary path %s', sourcePath, tempPath)
    end

    if os.rename(tempPath, destinationPath) then
        return true
    end

    if LrFileUtils.exists(destinationPath) == 'file' then
        local deleted = LrFileUtils.delete(destinationPath)
        if not deleted then
            local removedTemp = LrFileUtils.delete(tempPath)
            if not removedTemp then
                return false, string.format('Failed removing existing file at %s and temporary file at %s', destinationPath, tempPath)
            end
            return false, string.format('Failed removing existing file at %s', destinationPath)
        end

        if os.rename(tempPath, destinationPath) then
            return true
        end
    end

    local removedTemp = LrFileUtils.delete(tempPath)
    if not removedTemp then
        return false, string.format('Failed replacing %s with %s and cleaning temporary file %s', destinationPath, sourcePath, tempPath)
    end

    return false, string.format('Failed replacing %s with %s', destinationPath, sourcePath)
end

local function copySlideshowHelper(destinationDirectory)
    local helperSourcePath = LrPathUtils.child(_PLUGIN.path, SLIDESHOW_HELPER_NAME)
    local helperDestinationPath = LrPathUtils.child(destinationDirectory, SLIDESHOW_HELPER_NAME)

    if LrFileUtils.exists(helperSourcePath) ~= 'file' then
        return false, string.format('Missing slideshow helper script in plugin bundle: %s', helperSourcePath)
    end

    local copied, err = copyFileReplacingExisting(helperSourcePath, helperDestinationPath)
    if not copied then
        return false, string.format('Failed copying slideshow helper from %s to %s: %s', helperSourcePath, helperDestinationPath, err)
    end

    return true
end

local function buildSlideshowCommand(scriptPath, effectiveSettings, destinationDirectory)
    local deviceHost = effectiveSettings.bloomin8DeviceHost or ''
    local galleryName = effectiveSettings.bloomin8GalleryName or ''
    local duration = effectiveSettings.bloomin8Duration or '120'
    local randomOrder = effectiveSettings.bloomin8RandomOrder
    local orientation = effectiveSettings.bloomin8Orientation or ''

    local cmd = string.format(
        'bash %q --host %q --image-dir %q --duration %q',
        scriptPath, deviceHost, destinationDirectory, duration
    )

    if galleryName ~= '' then
        cmd = cmd .. string.format(' --gallery %q', galleryName)
    end

    if orientation ~= '' then
        cmd = cmd .. string.format(' --frame-orientation %q', orientation)
    end

    if randomOrder then
        cmd = cmd .. ' --random'
    end

    return cmd
end

local function writeSlideshowWrapper(destinationDirectory, effectiveSettings)
    local helperPath = LrPathUtils.child(destinationDirectory, SLIDESHOW_HELPER_NAME)
    local wrapperPath = LrPathUtils.child(destinationDirectory, SLIDESHOW_WRAPPER_NAME)
    local cmd = buildSlideshowCommand(helperPath, effectiveSettings, destinationDirectory)
    local file, openErr = io.open(wrapperPath, 'w')
    if not file then
        return false, nil, string.format('Failed creating slideshow wrapper %s: %s', wrapperPath, tostring(openErr))
    end

    local wrapperContent = string.format('#!/usr/bin/env bash\n%s "$@"\n', cmd)
    local okWrite, writeErr = file:write(wrapperContent)
    file:close()

    if not okWrite then
        return false, nil, string.format('Failed writing slideshow wrapper %s: %s', wrapperPath, tostring(writeErr))
    end

    return true, wrapperPath, nil
end

function PublishServiceProvider.processRenderedPhotos(functionContext, exportContext)
    local exportSession = exportContext.exportSession
    local exportSettings = assert(exportContext.propertyTable)
    local baseDirectory = exportSettings.bloomin8LocalDirectory

    -- Resolve per-collection settings
    local publishedCollection = exportContext.publishedCollection
    local collectionName = (publishedCollection and publishedCollection:getName()) or ''
    local collectionInfo = (publishedCollection and publishedCollection:getCollectionInfoSummary())
    local collectionSettings = (collectionInfo and collectionInfo.collectionSettings) or {}

    -- Gallery name: use collection setting if set, otherwise fall back to collection name
    local galleryName = collectionSettings.bloomin8GalleryName
    if galleryName == nil or galleryName == '' then
        galleryName = collectionName
    end

    if galleryName == '' then
        local err = 'Cannot determine gallery name: collection name is empty and no gallery name is configured in the collection settings.'
        LrDialogs.message('Bloomin8 Publish Service', err, 'critical')
        LrErrors.throwUserError(err)
    end

    -- Each collection exports to a subdirectory named after the gallery
    local destinationDirectory = LrPathUtils.child(baseDirectory, galleryName)

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
            local copied, copyErr = copyFileReplacingExisting(pathOrMessage, destinationPath)

            if copied then
                if rendition.uploadSucceeded then
                    rendition:uploadSucceeded(destinationPath)
                end
            else
                if rendition.uploadFailed then
                    rendition:uploadFailed(string.format('Failed copying %s to %s: %s', pathOrMessage, destinationPath, copyErr))
                end
            end
        end
    end

    local deviceHost = exportSettings.bloomin8DeviceHost or ''
    if deviceHost ~= '' then
        -- Merge service-level and collection-level settings for the wrapper script
        local effectiveSettings = {
            bloomin8DeviceHost  = deviceHost,
            bloomin8GalleryName = galleryName,
            bloomin8Duration    = collectionSettings.bloomin8Duration    or '120',
            bloomin8RandomOrder = collectionSettings.bloomin8RandomOrder,
            bloomin8Orientation = collectionSettings.bloomin8Orientation or 'portrait',
        }

        local ok, wrapperPath, err = writeSlideshowWrapper(destinationDirectory, effectiveSettings)
        if not ok then
            LrDialogs.message('Bloomin8 Publish Service', err, 'critical')
            LrErrors.throwUserError(err)
        end

        -- Wrapper is primarily for manual re-runs from Terminal with persisted settings.
        local cmd = string.format('bash %q', wrapperPath)

        -- os.execute is unavailable in Lightroom's Lua sandbox; use io.popen
        -- Append exit-code sentinel so we can detect failures.
        local handle = io.popen('{ ' .. cmd .. '; }; printf "\\nBLOOMIN8_EXIT:%d" $?', 'r')
        local output = handle and handle:read('*all') or ''
        if handle then handle:close() end

        local exitCode = tonumber(output:match('BLOOMIN8_EXIT:(%d+)'))
        if exitCode == nil or exitCode ~= 0 then
            local msg = string.format(
                'Slideshow upload finished with errors (exit code %s).\nCheck the Lightroom log for details.\n%s',
                tostring(exitCode),
                LIGHTROOM_LOG_HINT_MULTILINE
            )
            LrDialogs.message('Bloomin8 Publish Service', msg, 'warning')
        end
    end
end

return PublishServiceProvider
