/*******************************************************************************
 * The MIT License (MIT)
 * 
 * Copyright (c) 2017 Jean-David Gadina - www.xs-labs.com
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 ******************************************************************************/

/*!
 * @file        GitHubInstallWindowController.m
 * @copyright   (c) 2017, Jean-David Gadina - www.xs-labs.com
 */

#import "GitHubInstallWindowController.h"
#import "GitHubProgressWindowController.h"
#import "GitHubRelease.h"
#import "GitHubReleaseAsset.h"

NS_ASSUME_NONNULL_BEGIN

@interface GitHubInstallWindowController() < NSURLSessionDownloadDelegate >

@property( atomic, readwrite, strong, nullable )          GitHubReleaseAsset             * asset;
@property( atomic, readwrite, strong, nullable )          GitHubRelease                  * githubRelease;
@property( atomic, readwrite, strong, nullable )          GitHubProgressWindowController * progressWindowController;
@property( atomic, readwrite, strong, nullable )          NSString                       * title;
@property( atomic, readwrite, strong, nullable )          NSString                       * message;
@property( atomic, readwrite, strong, nullable )          NSAttributedString             * releaseNotes;
@property( atomic, readwrite, assign           )          BOOL                             installingUpdate;
@property( atomic, readwrite, assign           )          BOOL                             canceled;
@property( atomic, readwrite, strong           )          dispatch_queue_t                 queue;
@property( atomic, readwrite, strong, nullable ) IBOutlet NSTextView                     * textView;

- ( IBAction )install: ( nullable id )sender;
- ( IBAction )cancel: ( nullable id )sender;
- ( IBAction )viewOnGitHub: ( nullable id )sender;
- ( void )displayErrorWithMessage: ( NSString * )message;
- ( void )displayErrorWithTitle: ( NSString * )title message: ( NSString * )message;
- ( void )displayError: ( NSError * )error;
- ( void )download;
- ( void )stoppedInstalling;
- ( void )installFromZIP: ( NSURL * )location;

@end

NS_ASSUME_NONNULL_END

@implementation GitHubInstallWindowController

- ( instancetype )initWithAsset: ( GitHubReleaseAsset * )asset release: ( GitHubRelease * )release
{
    if( ( self = [ self init ] ) )
    {
        self.asset         = asset;
        self.githubRelease = release;
    }
    
    return self;
}

- ( instancetype )init
{
    return [ self initWithWindowNibName: NSStringFromClass( [ self class ] ) ];
}

- ( instancetype )initWithWindow: ( nullable NSWindow * )window
{
    if( ( self = [ super initWithWindow: window ] ) )
    {
        self.queue = dispatch_queue_create( "com.xs-labs.GitHubInstallWindowController", DISPATCH_QUEUE_SERIAL );
    }
    
    return self;
}

- ( nullable instancetype )initWithCoder: ( NSCoder * )coder
{
    if( ( self = [ super initWithCoder: coder ] ) )
    {
        self.queue = dispatch_queue_create( "com.xs-labs.GitHubInstallWindowController", DISPATCH_QUEUE_SERIAL );
    }
    
    return self;
}

- ( void )windowDidLoad
{
    NSString * app;
    NSString * version;
    
    [ super windowDidLoad ];
    
    self.window.title                      = NSLocalizedString( @"Software Update", @"" );
    self.window.titlebarAppearsTransparent = YES;
    self.window.titleVisibility            = NSWindowTitleHidden;
    
    self.textView.textContainerInset = NSMakeSize( 10.0, 20.0 );
    
    app     = [ [ NSBundle mainBundle ] objectForInfoDictionaryKey: @"CFBundleName" ];
    version = [ [ NSBundle mainBundle ] objectForInfoDictionaryKey: @"CFBundleShortVersionString" ];
    
    if( app.length == 0 )
    {
        self.title = NSLocalizedString( @"A software update is available available!", @"" );
    }
    else
    {
        self.title = [ NSString stringWithFormat: NSLocalizedString( @"A new version of %@ is available!", @"" ), app ];
    }
    
    if( version.length == 0 )
    {
        self.message = [ NSString stringWithFormat: NSLocalizedString( @"Version %@ can be is available. Would you like to install it now?", @"" ), self.githubRelease.tagName ];
    }
    else
    {
        self.message = [ NSString stringWithFormat: NSLocalizedString( @"Version %@ is available. You have version %@. Would you like to install the new version now?", @"" ), self.githubRelease.tagName, version ];
    }
    
    self.releaseNotes = [ [ NSAttributedString alloc ] initWithString: self.githubRelease.body attributes: nil ];
}

- ( IBAction )install: ( nullable id )sender
{
    NSString * app;
    
    ( void )sender;
    
    app = [ [ NSBundle mainBundle ] objectForInfoDictionaryKey: @"CFBundleName" ];
    
    self.window.isVisible                       = NO;
    self.installingUpdate                       = YES;
    self.progressWindowController               = [ GitHubProgressWindowController new ];
    self.progressWindowController.progress      = 0.0;
    self.progressWindowController.progressMin   = 0.0;
    self.progressWindowController.progressMax   = self.asset.size;
    self.progressWindowController.indeterminate = YES;
    
    if( app.length == 0 )
    {
        self.progressWindowController.title = NSLocalizedString( @"Downloading software update", @"" );
    }
    else
    {
        self.progressWindowController.title = [ NSString stringWithFormat: NSLocalizedString( @"Downloading %@ %@", @"" ), app, self.githubRelease.tagName ];
    }
    
    [ self download ];
    [ self.progressWindowController showWindow: nil ];
    [ self.progressWindowController.window center ];
    [ NSApp runModalForWindow: self.progressWindowController.window ];
}

- ( IBAction )cancel: ( nullable id )sender
{
    ( void )sender;
    
    [ self.window close ];
}

- ( IBAction )viewOnGitHub: ( nullable id )sender
{
    ( void )sender;
    
    [ [ NSWorkspace sharedWorkspace ] openURL: self.githubRelease.htmlURL ];
}

- ( void )displayErrorWithMessage: ( NSString * )message
{
    [ self displayErrorWithTitle: @"Error" message: message ];
}

- ( void )displayErrorWithTitle: ( NSString * )title message: ( NSString * )message;
{
    NSError * error;
    
    error = [ NSError errorWithDomain: NSCocoaErrorDomain code: -1 userInfo: @{ NSLocalizedDescriptionKey : title, NSLocalizedRecoverySuggestionErrorKey : message } ];
    
    [ self displayError: error ];
}

- ( void )displayError: ( NSError * )error
{
    dispatch_async
    (
        dispatch_get_main_queue(),
        ^( void )
        {
            NSAlert * alert;
            
            alert = [ NSAlert alertWithError: error ];
            
            [ alert runModal ];
        }
    );
}

- ( void )download
{
    self.canceled = NO;
                    
    dispatch_async
    (
        self.queue,
        ^( void )
        {
            NSURLSession             * session;
            NSURLSessionDownloadTask * task;
            
            session = [ NSURLSession sessionWithConfiguration: [ NSURLSessionConfiguration defaultSessionConfiguration ] delegate: self delegateQueue: [ NSOperationQueue mainQueue ] ];
            task    = [ session downloadTaskWithURL: self.asset.downloadURL ];
            
            [ task resume ];
            
            dispatch_sync
            (
                dispatch_get_main_queue(),
                ^( void )
                {
                    __weak __typeof__( self ) ws = self;
                    
                    self.progressWindowController.cancel = ^( void )
                    {
                        __strong __typeof__( self ) ss = ws;
                        
                        ss.canceled = YES;
                        
                        [ task cancel ];
                        [ ss stoppedInstalling ];
                    };
                }
            );
        }
    );
}

- ( void )stoppedInstalling
{
    [ self.progressWindowController.window close ];
    [ NSApp stopModal ];
    
    self.window.isVisible         = YES;
    self.progressWindowController = nil;
    self.installingUpdate         = NO;
}

- ( void )installFromZIP: ( NSURL * )location
{
    ( void )location;
    
    self.progressWindowController.indeterminate = YES;
    self.progressWindowController.progress      = 0.0;
    self.progressWindowController.progressMax   = 0.0;
    
    if( [ [ NSFileManager defaultManager ] fileExistsAtPath: location.path isDirectory: nil ] == NO )
    {
        [ self stoppedInstalling ];
        [ self displayErrorWithMessage: NSLocalizedString( @"Cannot find the downloaded file.", @"" ) ];
        
        return;
    }
    
    [ self stoppedInstalling ];
    [ self.window close ];
}

#pragma mark - NSURLSessionDownloadDelegate

- ( void )URLSession: ( NSURLSession * )session downloadTask: ( NSURLSessionDownloadTask * )downloadTask didWriteData: ( int64_t )bytesWritten totalBytesWritten: ( int64_t )totalBytesWritten totalBytesExpectedToWrite: ( int64_t )totalBytesExpectedToWrite
{
    ( void )session;
    ( void )downloadTask;
    ( void )bytesWritten;
    
    self.progressWindowController.indeterminate = NO;
    self.progressWindowController.progress      = totalBytesWritten;
    self.progressWindowController.progressMax   = totalBytesExpectedToWrite;
}

- ( void )URLSession: ( NSURLSession * )session task: ( NSURLSessionTask * )task didCompleteWithError: ( NSError * )error
{
    ( void )session;
    ( void )task;
    
    if( error != nil && self.canceled == NO )
    {
        [ self stoppedInstalling ];
        [ self displayError: error ];
    }
}

- ( void )URLSession: ( NSURLSession * )session downloadTask: ( NSURLSessionDownloadTask * )downloadTask didFinishDownloadingToURL: ( NSURL * )location
{
    ( void )session;
    ( void )downloadTask;
    
    [ self installFromZIP: location ];
}

@end
