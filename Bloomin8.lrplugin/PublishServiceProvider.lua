local LrDialogs = import 'LrDialogs'
local LrErrors = import 'LrErrors'
local LrFileUtils = import 'LrFileUtils'
local LrLogger = import 'LrLogger'
local LrPathUtils = import 'LrPathUtils'
local LrProgressScope = import 'LrProgressScope'
local LrView = import 'LrView'

local bind = LrView.bind

local logger = LrLogger('bloomin8')
do
    local enabledLogfile, enableErr = pcall(function()
        logger:enable('logfile')
    end)

    if not enabledLogfile then
        local enabledPrint = pcall(function()
            logger:enable('print')
        end)

        if enabledPrint then
            logger:warn(string.format(
                '[logging] Falling back to print logging because logfile logging could not be enabled: %s',
                tostring(enableErr)
            ))
        else
            pcall(function()
                print(string.format(
                    '[bloomin8][logging] Failed to enable logfile logging (%s) and print logging fallback.',
                    tostring(enableErr)
                ))
            end)
        end
    end
end

local PublishServiceProvider = {}
local SLIDESHOW_HELPER_NAME = 'bloomin8-gallery-slideshow.sh'
local SLIDESHOW_WRAPPER_NAME = 'bloomin8-run-slideshow.sh'
local LIGHTROOM_LOG_HINT_INLINE = 'If upload fails, check the Bloomin8 plugin log: macOS ~/Library/Logs/Adobe/Lightroom/LrClassicLogs/bloomin8.log ; Windows %AppData%\\Adobe\\Lightroom\\Logs\\bloomin8.log'
local LIGHTROOM_LOG_HINT_MULTILINE = 'Bloomin8 plugin log:\n  macOS: ~/Library/Logs/Adobe/Lightroom/LrClassicLogs/bloomin8.log\n  Windows: %AppData%\\Adobe\\Lightroom\\Logs\\bloomin8.log'
-- Sentinel token appended to popen output so the shell exit code can be parsed.
local EXIT_SENTINEL = 'BLOOMIN8_EXIT'

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
    local collectionSettings = info and info.collectionSettings
    if not collectionSettings then
        logger:warn('[collectionSettings] Lightroom did not provide collectionSettings for the current item')
        return f:group_box {
            title = 'Bloomin8 Collection Settings',
            fill_horizontal = 1,

            f:static_text {
                title = 'Collection settings are unavailable for this item.',
                fill_horizontal = 1,
            },
        }
    end

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

    return f:group_box {
        title = 'Bloomin8 Collection Settings',
        fill_horizontal = 1,
        bind_to_object = collectionSettings,

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

        f:row {
            spacing = f:control_spacing(),
            f:static_text {
                title = 'Frame orientation:',
                alignment = 'right',
                width = 160,
            },
            f:popup_menu {
                value = bind 'bloomin8Orientation',
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
    -- os.rename is not available in Lightroom's Lua sandbox, so delete-then-copy
    -- is used to replace an existing destination file.
    if LrFileUtils.exists(destinationPath) == 'file' then
        local deleted = LrFileUtils.delete(destinationPath)
        if not deleted then
            return false, string.format('Failed to delete existing file at %s', destinationPath)
        end
    end

    local copied = LrFileUtils.copy(sourcePath, destinationPath)
    if not copied then
        return false, string.format('Failed copying %s to %s', sourcePath, destinationPath)
    end

    return true
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

-- Runs a shell command via io.popen, capturing all output and the exit code.
-- Returns: exitCode (number or nil), lines (table of output strings).
local function runShellCommand(cmd)
    -- Redirect stderr to stdout so die() messages are captured alongside normal output.
    local handle = io.popen('{ ' .. cmd .. '; } 2>&1; printf "\\n' .. EXIT_SENTINEL .. ':%d" $?', 'r')
    local output = handle and handle:read('*all') or ''
    if handle then handle:close() end
    local exitCode = tonumber(output:match(EXIT_SENTINEL .. ':(%d+)'))
    local scriptOutput = output:gsub('\n' .. EXIT_SENTINEL .. ':%d+%s*$', '')
    local lines = {}
    for line in (scriptOutput .. '\n'):gmatch('([^\n]*)\n') do
        lines[#lines + 1] = line
    end
    if #lines > 0 and lines[#lines] == '' then
        table.remove(lines)
    end
    return exitCode, lines
end

-- Logs each line of shell output to the plugin log.
-- LrLogger silently drops multi-line strings, so lines are logged individually.
local function logShellLines(lines, level, tag)
    for i, line in ipairs(lines) do
        logger[level](logger, string.format('[%s:%d] %s', tag, i, line))
    end
end

-- Builds the --mode begin command: verifies device connectivity, ensures the
-- gallery exists, and stops any active slideshow before per-image uploads.
local function buildSetupCommand(scriptPath, effectiveSettings, destinationDirectory)
    local deviceHost = effectiveSettings.bloomin8DeviceHost or ''
    local galleryName = effectiveSettings.bloomin8GalleryName or ''
    local orientation = effectiveSettings.bloomin8Orientation or 'portrait'
    return string.format(
        'bash %q --mode begin --host %q --gallery %q --frame-orientation %q --image-dir %q',
        scriptPath, deviceHost, galleryName, orientation, destinationDirectory
    )
end

-- Builds the --mode upload-one command: processes and uploads exactly one image.
local function buildUploadOneCommand(scriptPath, effectiveSettings, destinationDirectory, filePath)
    local deviceHost = effectiveSettings.bloomin8DeviceHost or ''
    local galleryName = effectiveSettings.bloomin8GalleryName or ''
    local orientation = effectiveSettings.bloomin8Orientation or 'portrait'
    return string.format(
        'bash %q --mode upload-one --host %q --gallery %q --frame-orientation %q --image-dir %q --file %q',
        scriptPath, deviceHost, galleryName, orientation, destinationDirectory, filePath
    )
end

-- Builds the --mode finish command: sends POST /show to start gallery playback.
local function buildFinishCommand(scriptPath, effectiveSettings)
    local deviceHost = effectiveSettings.bloomin8DeviceHost or ''
    local galleryName = effectiveSettings.bloomin8GalleryName or ''
    local duration = effectiveSettings.bloomin8Duration or '120'
    return string.format(
        'bash %q --mode finish --host %q --gallery %q --duration %q',
        scriptPath, deviceHost, galleryName, duration
    )
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

    logger:info(string.format(
        '[publishState] processRenderedPhotos: collection=%q galleryName=%q destinationDirectory=%q',
        collectionName, galleryName, destinationDirectory
    ))

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

    local nRenditions    = 0
    local nFailed        = 0
    local failedNames    = {}
    -- Locally-copied renditions whose publish state is committed only after a
    -- successful device upload (or immediately when no device host is configured).
    local localSucceeded = {}

    for _, rendition in exportSession:renditions { stopIfCanceled = true } do
        nRenditions = nRenditions + 1

        -- previousId is the path stored by the last successful recordPublishedPhotoId call,
        -- or nil when this photo has never been successfully published.
        local previousId = rendition.publishedPhotoId
        local photo = rendition.photo
        local photoName = '(unknown)'

        if type(photo) == 'function' then
            local ok, resolvedPhoto = pcall(function()
                return rendition:photo()
            end)

            photo = ok and resolvedPhoto or nil
        end

        if photo and type(photo.getFormattedMetadata) == 'function' then
            photoName = photo:getFormattedMetadata('fileName') or photoName
        end

        logger:info(string.format(
            '[publishState] rendition #%d: photo=%q previousId=%s',
            nRenditions, photoName,
            previousId and string.format('%q', previousId) or 'nil (never published)'
        ))

        local success, pathOrMessage = rendition:waitForRender()

        if not success then
            nFailed = nFailed + 1
            failedNames[#failedNames + 1] = photoName
            logger:warn(string.format(
                '[publishState] render FAILED for %q: %s', photoName, tostring(pathOrMessage)
            ))
            rendition:uploadFailed(pathOrMessage)
        else
            local outputFilename = LrPathUtils.leafName(pathOrMessage)
            local destinationPath = LrPathUtils.child(destinationDirectory, outputFilename)

            logger:info(string.format(
                '[publishState] rendered %q -> destinationPath=%q (previousId match: %s)',
                photoName, destinationPath,
                (previousId == destinationPath) and 'yes' or
                    (previousId == nil and 'nil – first publish' or
                     string.format('NO (was %q)', previousId))
            ))

            local copied, copyErr = copyFileReplacingExisting(pathOrMessage, destinationPath)

            if copied then
                -- Defer recordPublishedPhotoId until after the device upload so that
                -- a failed device upload leaves these photos in the publish queue.
                localSucceeded[#localSucceeded + 1] = {
                    rendition       = rendition,
                    destinationPath = destinationPath,
                    photoName       = photoName,
                }
                logger:info(string.format(
                    '[publishState] local copy succeeded for %q -> %q (publish state deferred)',
                    photoName, destinationPath
                ))
            else
                nFailed = nFailed + 1
                failedNames[#failedNames + 1] = photoName
                local failMsg = string.format('Failed copying %s to %s: %s', pathOrMessage, destinationPath, tostring(copyErr))
                if rendition.uploadFailed then
                    rendition:uploadFailed(failMsg)
                end
                logger:error(string.format(
                    '[publishState] uploadFailed for %q: %s', photoName, failMsg
                ))
            end
        end
    end

    local nSucceeded = #localSucceeded

    logger:info(string.format(
        '[publishState] publish loop complete: renditions=%d succeeded=%d failed=%d',
        nRenditions, nSucceeded, nFailed
    ))

    -- Surface a warning if any file copies failed so the user can see their publish
    -- state is not fully committed.  These photos will remain in "New Photos to
    -- Publish" or "Modified Photos to Re-publish" and should be retried.
    if nFailed > 0 then
        local msg = string.format(
            '%d of %d photo(s) could not be copied to the local publish directory and were NOT marked as published:\n\n%s\n\nThey will remain in "New Photos to Publish" until a successful publish. Check the Lightroom log for details.\n%s',
            nFailed, nRenditions,
            table.concat(failedNames, '\n'),
            LIGHTROOM_LOG_HINT_MULTILINE
        )
        logger:error('[publishState] ' .. msg)
        LrDialogs.message('Bloomin8 Publish Service', msg, 'warning')
    end

    local deviceHost = exportSettings.bloomin8DeviceHost or ''
    if deviceHost ~= '' then
        -- Merge service-level and collection-level settings
        local effectiveSettings = {
            bloomin8DeviceHost  = deviceHost,
            bloomin8GalleryName = galleryName,
            bloomin8Duration    = collectionSettings.bloomin8Duration    or '120',
            bloomin8RandomOrder = collectionSettings.bloomin8RandomOrder,
            bloomin8Orientation = collectionSettings.bloomin8Orientation or 'portrait',
        }

        -- Always write the wrapper script so it can be re-run manually from Terminal
        -- for a full gallery sync (it uses --image-dir, not --file).
        local ok, wrapperPath, err = writeSlideshowWrapper(destinationDirectory, effectiveSettings)
        if not ok then
            LrDialogs.message('Bloomin8 Publish Service', err, 'critical')
            LrErrors.throwUserError(err)
        end

        if #localSucceeded == 0 then
            -- Nothing was successfully rendered/copied; skip the device upload entirely.
            logger:info('[publishState] no files succeeded; skipping device upload')
            return
        end

        local helperPath = LrPathUtils.child(destinationDirectory, SLIDESHOW_HELPER_NAME)

        -- Step 1: Setup – verify device connectivity, ensure gallery exists, stop slideshow.
        local setupCmd = buildSetupCommand(helperPath, effectiveSettings, destinationDirectory)
        logger:info('[publishState] device setup command: ' .. setupCmd)
        local setupExit, setupLines = runShellCommand(setupCmd)
        local setupLevel = (setupExit ~= 0) and 'error' or 'info'
        logger[setupLevel](logger, string.format(
            '[setupOutput] exit=%s lines=%d', tostring(setupExit), #setupLines
        ))
        logShellLines(setupLines, setupLevel, 'setupOutput')

        if setupExit == nil or setupExit ~= 0 then
            -- Device is unreachable or gallery setup failed; re-queue all photos.
            for _, item in ipairs(localSucceeded) do
                local failMsg = string.format(
                    'Device setup failed (exit code %s); photo will be re-queued for publish',
                    tostring(setupExit)
                )
                item.rendition:uploadFailed(failMsg)
                logger:warn(string.format(
                    '[publishState] uploadFailed (setup error) for %q: %s',
                    item.photoName, failMsg
                ))
            end
            local tailLines = {}
            local MAX_TAIL_LINES = 10
            local tailStart = math.max(1, #setupLines - MAX_TAIL_LINES + 1)
            for i = tailStart, #setupLines do
                tailLines[#tailLines + 1] = setupLines[i]
            end
            local outputSnippet = table.concat(tailLines, '\n')
            local msg
            if outputSnippet ~= '' then
                msg = string.format(
                    'Device setup failed (exit code %s).\n%d photo(s) have been re-queued and will appear in "New/Modified Photos to Publish".\n\nScript output:\n%s\n\n%s',
                    tostring(setupExit), #localSucceeded, outputSnippet, LIGHTROOM_LOG_HINT_MULTILINE
                )
            else
                msg = string.format(
                    'Device setup failed (exit code %s).\n%d photo(s) have been re-queued and will appear in "New/Modified Photos to Publish".\n%s',
                    tostring(setupExit), #localSucceeded, LIGHTROOM_LOG_HINT_MULTILINE
                )
            end
            LrDialogs.message('Bloomin8 Publish Service', msg, 'warning')
            return
        end

        -- Step 2: Upload each image individually so partial success can be recorded
        -- and per-image progress is visible in Lightroom.
        local nDeviceUploaded = 0
        local deviceFailed = {}

        local progress = LrProgressScope {
            title = string.format('Bloomin8: uploading %d photo(s) to %s', #localSucceeded, deviceHost),
            functionContext = functionContext,
        }

        for i, item in ipairs(localSucceeded) do
            if progress:isCanceled() then
                -- Mark all remaining images as failed so they are re-queued.
                for j = i, #localSucceeded do
                    local remaining = localSucceeded[j]
                    remaining.rendition:uploadFailed('Upload canceled; photo will be re-queued for publish')
                    deviceFailed[#deviceFailed + 1] = remaining
                    logger:warn(string.format(
                        '[publishState] uploadFailed (canceled) for %q', remaining.photoName
                    ))
                end
                break
            end

            progress:setCaption(string.format(
                'Uploading %s (%d of %d)', item.photoName, i, #localSucceeded
            ))
            progress:setPortionComplete(i - 1, #localSucceeded)

            local uploadCmd = buildUploadOneCommand(
                helperPath, effectiveSettings, destinationDirectory, item.destinationPath
            )
            logger:info(string.format(
                '[publishState] upload-one command (%d/%d): %s', i, #localSucceeded, uploadCmd
            ))
            local exitCode, lines = runShellCommand(uploadCmd)
            local level = (exitCode ~= 0) and 'error' or 'info'
            logger[level](logger, string.format(
                '[uploadOutput:%s] exit=%s lines=%d', item.photoName, tostring(exitCode), #lines
            ))
            logShellLines(lines, level, 'uploadOutput:' .. item.photoName)

            if exitCode == 0 then
                nDeviceUploaded = nDeviceUploaded + 1
                item.rendition:recordPublishedPhotoId(item.destinationPath)
                logger:info(string.format(
                    '[publishState] recordPublishedPhotoId(%q) for %q',
                    item.destinationPath, item.photoName
                ))
            else
                local failMsg = string.format(
                    'Device upload failed (exit code %s); photo will be re-queued for publish',
                    tostring(exitCode)
                )
                item.rendition:uploadFailed(failMsg)
                deviceFailed[#deviceFailed + 1] = item
                logger:warn(string.format(
                    '[publishState] uploadFailed (device error) for %q: %s',
                    item.photoName, failMsg
                ))
            end
        end

        progress:done()

        -- Step 3: Start the slideshow if at least one image was uploaded successfully.
        if nDeviceUploaded > 0 then
            local finishCmd = buildFinishCommand(helperPath, effectiveSettings)
            logger:info('[publishState] finish command: ' .. finishCmd)
            local finishExit, finishLines = runShellCommand(finishCmd)
            local finishLevel = (finishExit ~= 0) and 'warn' or 'info'
            logger[finishLevel](logger, string.format(
                '[finishOutput] exit=%s lines=%d', tostring(finishExit), #finishLines
            ))
            logShellLines(finishLines, finishLevel, 'finishOutput')
            if finishExit ~= 0 then
                logger:warn(string.format(
                    '[publishState] POST /show failed (exit code %s); %d photo(s) are on the device',
                    tostring(finishExit), nDeviceUploaded
                ))
            end
        end

        -- Step 4: Report any per-image upload failures.
        if #deviceFailed > 0 then
            local failNames = {}
            for _, item in ipairs(deviceFailed) do
                failNames[#failNames + 1] = item.photoName
            end
            local msg = string.format(
                '%d of %d photo(s) failed to upload to the device and have been re-queued:\n\n%s\n\n%d photo(s) uploaded successfully.\n%s',
                #deviceFailed, #localSucceeded,
                table.concat(failNames, '\n'),
                nDeviceUploaded,
                LIGHTROOM_LOG_HINT_MULTILINE
            )
            LrDialogs.message('Bloomin8 Publish Service', msg, 'warning')
        end
    else
        -- No device host configured: commit publish state immediately after local copy.
        for _, item in ipairs(localSucceeded) do
            item.rendition:recordPublishedPhotoId(item.destinationPath)
            logger:info(string.format(
                '[publishState] recordPublishedPhotoId(%q) for %q',
                item.destinationPath, item.photoName
            ))
        end
    end
end

-- Percent-encodes a string for use as a URI query-parameter value.
local function urlEncode(s)
    return (s:gsub('([^%w%-%.%_%~])', function(c)
        return string.format('%%%02X', string.byte(c))
    end))
end

-- Called by Lightroom when photos are removed from the published collection.
-- photoId is the local destination path stored by rendition:recordPublishedPhotoId.
function PublishServiceProvider.deletePublishedPhotos(functionContext, publishSettings, arrayOfPhotoIds)
    local deviceHost = publishSettings.bloomin8DeviceHost or ''
    local errors = {}

    for _, photoId in ipairs(arrayOfPhotoIds) do
        -- Delete local file.
        if LrFileUtils.exists(photoId) == 'file' then
            local deleted = LrFileUtils.delete(photoId)
            if not deleted then
                errors[#errors + 1] = string.format('Failed to delete local file: %s', photoId)
            end
        end

        -- Delete from device if a host is configured.
        -- Filename and gallery name are percent-encoded so special characters are safe in the URL.
        -- deviceHost is validated to contain only characters valid in a hostname, IP, or port,
        -- preventing shell metacharacter injection when it is interpolated into the curl URL.
        if deviceHost ~= '' then
            if deviceHost:match('[^%w%.%-%:]') then
                errors[#errors + 1] = string.format(
                    'Device host %q contains invalid characters; skipping device delete for %s',
                    deviceHost, LrPathUtils.leafName(photoId)
                )
            else
                local parentDir = LrPathUtils.parent(photoId)
                if not parentDir then
                    errors[#errors + 1] = string.format(
                        'Cannot determine gallery from path %s; skipping device delete', photoId
                    )
                else
                    local filename = LrPathUtils.leafName(photoId)
                    local galleryName = LrPathUtils.leafName(parentDir)
                    local url = string.format('http://%s/image/delete?image=%s&gallery=%s',
                        deviceHost, urlEncode(filename), urlEncode(galleryName))
                    local curlCmd = string.format('curl -sf -X POST %q', url)
                    local handle = io.popen('{ ' .. curlCmd .. '; }; printf "\\nBLOOMIN8_EXIT:%d" $?', 'r')
                    local output = handle and handle:read('*all') or ''
                    if handle then handle:close() end
                    local exitCode = tonumber(output:match('BLOOMIN8_EXIT:(%d+)'))
                    if exitCode == nil then
                        errors[#errors + 1] = string.format(
                            'Failed to delete %s from device gallery %s (curl produced no exit code)',
                            filename, galleryName
                        )
                    elseif exitCode ~= 0 then
                        errors[#errors + 1] = string.format(
                            'Failed to delete %s from device gallery %s (curl exit %d)',
                            filename, galleryName, exitCode
                        )
                    end
                end
            end
        end
    end

    if #errors > 0 then
        LrDialogs.message(
            'Bloomin8 Publish Service',
            string.format('%d deletion(s) failed:\n', #errors) ..
                table.concat(errors, '\n') .. '\n' .. LIGHTROOM_LOG_HINT_MULTILINE,
            'warning'
        )
    end
end

return PublishServiceProvider
