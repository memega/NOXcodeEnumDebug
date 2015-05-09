# NOXcodeEnumDebug

This plugin is intended to simplify printing debug values of enums in Objective-C. When used, it creates a simple NSStringFrom... function for each NS_ENUM and NS_OPTIONS definition in the current file, returning enum values as NSStrings. 

For example, you have
```ruby
typedef NS_ENUM(NSInteger, NOXcodeEnum) {
    NOXcodeEnumNone,
    NOXcodeEnumSome,
    NOXcodeEnumMore,
};
```
The plugin creates function ```NSString *NSStringFromNOXcodeEnum(NOXcodeEnum value)``` just below the enum definition. Calling ```NSStringFromNOXcodeEnum(NOXcodeEnumNone)``` would yield ```@"NOXcodeEnumNone"```. 

Only NS_ENUM and NS_OPTIONS macros are supported, no plain c/c++ enums.

## Installation

Download the source, build the Xcode project and restart Xcode. The plugin will automatically be installed in ~/Library/Application Support/Developer/Shared/Xcode/Plug-ins. To uninstall, just remove the plugin from there (and restart Xcode).

### Usage

Select the menu ```Edit→Create NSStringFromXXX```.

### License

This project is licensed under the terms of the [MIT license](http://memega.mit-license.org/).
