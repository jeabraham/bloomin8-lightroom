return {
    LrSdkVersion = 6.0,
    LrSdkMinimumVersion = 6.0,
    LrToolkitIdentifier = 'com.bloomin8.lightroom.publish',
    LrPluginName = 'Bloomin8 Publish Service',
    LrPluginInfoUrl = 'https://bloomin8.readme.io/reference/get_deviceinfo',

	-- LrExportServiceProvider is correct here. Publish-only services still use
	-- LrExportServiceProvider in Info.lua; the 'only' value of supportsIncrementalPublish
	-- in PublishServiceProvider.lua is what hides the plugin from the plain Export dialog.
	LrExportServiceProvider = {
        title = 'Bloomin8 Publish Service',
        file = 'PublishServiceProvider.lua',
        small_icon = 'small_icon.png',
    },

    VERSION = {
        major = 0,
        minor = 1,
        revision = 0,
        build = 1,
    },
}
