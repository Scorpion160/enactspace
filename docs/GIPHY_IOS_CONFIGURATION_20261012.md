# GIPHY iOS configuration

The Flutter client selects its GIPHY API key by web/Android/iOS platform; iOS does not fall back to the Android key. Windows/Linux/macOS native applications have no configured key. The sync tool updates full source files, runs Flutter tests, prompts for the iOS API key and validates it directly with GIPHY without printing it. Existing web and Android defines are not changed.

The new iOS defines file is prepared at LOCALAPPDATA/EnactSpace/IOSRecipe/ios-client-defines.json. It contains the production API URL and iOS GIPHY key and preserves any pre-existing iOS values. It is not a complete iOS release recipe: iOS Firebase registration/configuration, bundle ID verification, signing and an Apple-capable build environment still need preparation. Do not publish client configuration files into the source repository.
