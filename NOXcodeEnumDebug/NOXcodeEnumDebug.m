/*
 The MIT License (MIT)
 Copyright © 2015 Yuriy Panfyorov
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import "NOXcodeEnumDebug.h"

#import "XcodeHeaders.h"

static NSString * const NOXcodeEnumDebugMenuItemTitle = @"Create NSStringFromXXX";
static NSString * const NOXcodeEnumDebugNSENUMRegularExpression = @"(typedef\\s?)?(?:NS_ENUM|NS_OPTIONS)\\(.*?\\,\\s*(.*?)\\s*\\)\\s*\\{(.*?)\\}\\;";
static NSString * const NOXcodeEnumDebugFunctionRegularExpression = @".*?\\#endif";

// value object
@interface _NOEnum : NSObject
@property (nonatomic) NSString *name;
@property (nonatomic) BOOL isTypedef;
@property (nonatomic) NSArray *constants;
@property (nonatomic) NSString *fullDefinition;
@end

@implementation _NOEnum
- (NSString *)description { return [NSString stringWithFormat:@"<_NOEnum|%p> %@%@ (%@)", self, self.name, (self.isTypedef ? @" (typedef)":@""), [self.constants componentsJoinedByString:@", "]]; }
@end

static NOXcodeEnumDebug *sharedPlugin;

@interface NOXcodeEnumDebug()

@property (nonatomic, weak) IDEIndex *index;

@end

@implementation NOXcodeEnumDebug

+ (void)pluginDidLoad:(NSBundle *)plugin
{
    static dispatch_once_t onceToken;
    NSString *currentApplicationName = [[NSBundle mainBundle] infoDictionary][@"CFBundleName"];
    if ([currentApplicationName isEqual:@"Xcode"]) {
        dispatch_once(&onceToken, ^{
            sharedPlugin = [[self alloc] initWithBundle:plugin];
        });
    }
}

+ (instancetype)sharedPlugin
{
    return sharedPlugin;
}

- (id)initWithBundle:(NSBundle *)plugin
{
    if (self = [super init]) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidFinishLaunching:) name:
         NSApplicationDidFinishLaunchingNotification object:[NSApplication sharedApplication ]];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(indexDidChange:) name:@"IDEIndexDidChangeNotification" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(indexDidChange:) name:@"IDEIndexDidIndexWorkspaceNotification" object:nil];
    }
    return self;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    NSMenuItem *editMenuItem = [[NSApp mainMenu] itemWithTitle:@"Edit"];
    if (editMenuItem)
    {
        [[editMenuItem submenu] addItem:[NSMenuItem separatorItem]];
        
        NSMenuItem *newMenuItem = [[NSMenuItem alloc] initWithTitle:NOXcodeEnumDebugMenuItemTitle action:@selector(createNSStringFrom:) keyEquivalent:@""];
        
        [newMenuItem setTarget:self];
        [[editMenuItem submenu] addItem:newMenuItem];
        [[editMenuItem submenu] addItem:[NSMenuItem separatorItem]];
    }
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)indexDidChange:(NSNotification *)sender
{
    self.index = sender.object;
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
    if ([menuItem.title isEqualToString:NOXcodeEnumDebugMenuItemTitle])
    {
        return (self.index != nil);
    }
    return YES;
}

- (void)createNSStringFrom:(id)sender
{
    DVTSourceTextView *focusedTextView = nil;
    if ([[self currentSourceCodeTextView] isKindOfClass:[DVTSourceTextView class]])
    {
        focusedTextView = (DVTSourceTextView *)[self currentSourceCodeTextView];
    }
    
    if (focusedTextView == nil) return;
    
    // only NS_ENUM and NS_OPTION are supported, so find those in the current document and store
    NSError *error;
    NSRegularExpression *enumExpression = [NSRegularExpression regularExpressionWithPattern:NOXcodeEnumDebugNSENUMRegularExpression
                                                                                    options:NSRegularExpressionDotMatchesLineSeparators
                                                                                      error:&error];
    
    NSMutableArray *currentDocumentNSENUMs = [NSMutableArray new];
    NSString *sourceString = [focusedTextView.textStorage.string copy];
    [enumExpression enumerateMatchesInString:sourceString
                                     options:NSMatchingReportProgress
                                       range:NSMakeRange(0, sourceString.length)
                                  usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
                                      if (result)
                                      {
                                          if (result.numberOfRanges == 4)
                                          {
                                              //
                                              NSRange enumTypedefRange = [result rangeAtIndex:1];
                                              NSString *enumName = [sourceString substringWithRange:[result rangeAtIndex:2]];
                                              
                                              _NOEnum *anEnum = [_NOEnum new];
                                              anEnum.name = enumName;
                                              anEnum.isTypedef = (enumTypedefRange.location != NSNotFound);
                                              anEnum.fullDefinition = [sourceString substringWithRange:[result rangeAtIndex:0]];
                                              [currentDocumentNSENUMs addObject:anEnum];
                                          }
                                      }
                                  }];
    
    // gather constants
    IDEIndexCollection *enumConstantCollection = [self.index allSymbolsMatchingKind:[DVTSourceCodeSymbolKind enumConstantSymbolKind] workspaceOnly:YES];
    for (NSUInteger i = 0; i < currentDocumentNSENUMs.count; i++)
    {
        _NOEnum *anEnum = currentDocumentNSENUMs[i];
        
        NSMutableArray *enumConstants = [NSMutableArray new];
        for(IDEIndexSymbol *enumConstantSymbol in enumConstantCollection.allObjects)
        {
            NSString *enumConstantName = [enumConstantSymbol.containerSymbol name];
            enumConstantName = [enumConstantName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if ([enumConstantName isEqualToString:anEnum.name])
            {
                [enumConstants addObject:enumConstantSymbol.name];
            }
        }
        anEnum.constants = enumConstants;
    }
    
    // finally, replace
    for (NSUInteger i = 0; i < currentDocumentNSENUMs.count; i++)
    {
        _NOEnum *anEnum = currentDocumentNSENUMs[i];
        
        NSString *enumFunctionName = [self enumFunctionNameForEnumNamed:anEnum.name];
        NSString *enumFunctionText = [self enumFunctionTextForEnumNamed:anEnum.name enumConstants:anEnum.constants isTypedef:anEnum.isTypedef];
        
        // check if there is a function already for that
        IDEIndexCollection *collection = [self.index allSymbolsMatchingName:enumFunctionName kind:nil];
        if ([collection.allObjects count])
        {
            // it exists, should remove current value
            // 1. find position of function name
            NSString *enumFunctionDeclaration = [@"FOUNDATION_EXPORT NSString *" stringByAppendingString:enumFunctionName];
            NSUInteger enumFunctionDeclarationIndex = [focusedTextView.textStorage.string rangeOfString:enumFunctionDeclaration].location;
            // 2. regex
            NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:NOXcodeEnumDebugFunctionRegularExpression
                                                                                   options:NSRegularExpressionDotMatchesLineSeparators
                                                                                     error:NULL];
            NSTextCheckingResult *result = [regex firstMatchInString:focusedTextView.textStorage.string
                                                             options:0
                                                               range:NSMakeRange(enumFunctionDeclarationIndex, focusedTextView.textStorage.string.length - enumFunctionDeclarationIndex)];
            if (result.numberOfRanges == 1)
            {
                NSRange firstRange = [result rangeAtIndex:0];
                [focusedTextView setSelectedRange:NSMakeRange(enumFunctionDeclarationIndex, NSMaxRange(firstRange) - enumFunctionDeclarationIndex + 1)];
                [focusedTextView delete:nil];
            }
        }
        
        // actually place
        NSRange actualRange = [focusedTextView.textStorage.string rangeOfString:anEnum.fullDefinition];
        [focusedTextView setSelectedRange:NSMakeRange(NSMaxRange(actualRange), 0)];
        [focusedTextView insertText:enumFunctionText];
        
        NSRange functionTextRange = [focusedTextView.textStorage.string rangeOfString:enumFunctionText];
        [focusedTextView _indentInsertedTextIfNecessaryAtRange:functionTextRange];
    }
}

- (id)currentEditor
{
    NSWindowController *currentWindowController = [[NSApp keyWindow] windowController];
    if ([currentWindowController isKindOfClass:NSClassFromString(@"IDEWorkspaceWindowController")])
    {
        IDEWorkspaceWindowController *workspaceController = (IDEWorkspaceWindowController *)currentWindowController;
        IDEEditorArea *editorArea = [workspaceController editorArea];
        IDEEditorContext *editorContext = [editorArea lastActiveEditorContext];
        return [editorContext editor];
    }
    return nil;
}

- (NSTextView *)currentSourceCodeTextView
{
    if ([[self currentEditor] isKindOfClass:NSClassFromString(@"IDESourceCodeEditor")])
    {
        IDESourceCodeEditor *editor = [self currentEditor];
        return editor.textView;
    }
    
    if ([[self currentEditor] isKindOfClass:NSClassFromString(@"IDESourceCodeComparisonEditor")])
    {
        IDESourceCodeComparisonEditor *editor = [self currentEditor];
        return editor.keyTextView;
    }
    
    return nil;
}

- (NSString *)enumFunctionNameForEnumNamed:(NSString *)enumName
{
    return [@"NSStringFrom" stringByAppendingString:[enumName stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:[[enumName substringToIndex:1] capitalizedString]]];
}

- (NSString *)enumFunctionTextForEnumNamed:(NSString *)enumName enumConstants:(NSArray *)enumConstants isTypedef:(BOOL)isTypedef
{
    // generate actual function
    NSString *functionName = [self enumFunctionNameForEnumNamed:enumName];
    NSString *functionText = [NSString stringWithFormat:@"\nFOUNDATION_EXPORT NSString *%@(%@%@ value);\n", functionName, isTypedef ? @"":@"enum ", enumName];
    functionText = [functionText stringByAppendingFormat:@"#ifndef _%@\n", functionName];
    functionText = [functionText stringByAppendingFormat:@"#define _%@\n", functionName];
    functionText = [functionText stringByAppendingFormat:@"NSString *%@(%@%@ value)\n{\nswitch(value) {\n", functionName, isTypedef ? @"":@"enum ", enumName];
    for (NSString *enumValue in enumConstants)
    {
        functionText = [functionText stringByAppendingFormat:@"case %@:\nreturn @\"%@\";\n", enumValue, enumValue];
    }
    functionText = [functionText stringByAppendingFormat:@"};\nreturn @\"Unknown %@ value\";\n}\n", enumName];
    functionText = [functionText stringByAppendingString:@"#endif"];
    return functionText;
}

@end
