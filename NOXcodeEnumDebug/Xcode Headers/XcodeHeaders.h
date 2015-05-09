//
//  Umbrella.h
//  SCXcodeSwitchExpander
//
//  Created by Yuriy Panfyorov on 08/05/15.
//  Copyright (c) 2015 Stefan Ceriu. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface DVTCompletingTextView : NSTextView
@end

@interface DVTSourceTextView : DVTCompletingTextView
- (struct _NSRange)_indentInsertedTextIfNecessaryAtRange:(struct _NSRange)arg1;
@end

@interface IDEIndexCollection : NSObject
- (id)allObjects;
@end

@interface IDEIndex : NSObject

- (id)allSymbolsMatchingName:(id)arg1 kind:(id)arg2;
- (id)allSymbolsMatchingKind:(id)arg1 workspaceOnly:(BOOL)arg2;

@end

@interface IDEIndexSymbol : NSObject
@property(readonly, nonatomic) NSString *name;
- (id)containerSymbol;
@end

@interface DVTSourceCodeSymbolKind : NSObject
+ (id)enumConstantSymbolKind;
+ (id)enumSymbolKind;
@end

@interface IDEEditorContext : NSObject
- (id)editor; // returns the current editor. If the editor is the code editor, the class is `IDESourceCodeEditor`
@end

@interface IDEEditorArea : NSObject
- (IDEEditorContext *)lastActiveEditorContext;
@end

@interface IDEWorkspaceWindowController : NSObject
- (IDEEditorArea *)editorArea;
@end

@interface IDESourceCodeEditor : NSObject
@property (retain) NSTextView *textView;
@end

@interface IDESourceCodeComparisonEditor : NSObject
@property (readonly) NSTextView *keyTextView;
@end
