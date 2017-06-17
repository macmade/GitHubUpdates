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
 * @file        GitHubUpdater.m
 * @copyright   (c) 2017, Jean-David Gadina - www.xs-labs.com
 */

#import "GitHubUpdater.h"
#import "GitHubRelease.h"
#import "GitHubReleaseAsset.h"
#import "GitHubProgressWindowController.h"
#import "GitHubInstallWindowController.h"
#import "Pair.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM( NSUInteger, GitHubUpdaterDisplayOptions )
{
    GitHubUpdaterDisplayOptionsDisplayErrors    = 1,
    GitHubUpdaterDisplayOptionsDisplayUI        = 2
};

@interface GitHubUpdater()

@property( atomic, readwrite, strong           ) dispatch_queue_t                 queue;
@property( atomic, readwrite, assign           ) BOOL                             checkingForUpdates;
@property( atomic, readwrite, strong, nullable ) GitHubProgressWindowController * progressWindowController;
@property( atomic, readwrite, strong, nullable ) GitHubInstallWindowController  * installWindowController;

- ( void )closeProgressWindow;
- ( void )displayErrorWithMessage: ( NSString * )message;
- ( void )displayErrorWithTitle: ( NSString * )title message: ( NSString * )message;
- ( void )displayError: ( NSError * )error;
- ( void )checkForUpdatesInBackgroundWithDisplayOptions: ( NSUInteger )options;
- ( void )getUpdatesAtURL: ( NSURL * )url displayOptions: ( NSUInteger )options;
- ( void )findUpdateWithData: ( NSData * )data displayOptions: ( NSUInteger )options;
- ( Pair< GitHubRelease *, GitHubReleaseAsset * > * )findBestAssetFromReleases: ( NSArray< GitHubRelease * > * )releases;
- ( void )proposeToInstallAsset: ( GitHubReleaseAsset * )asset release: ( GitHubRelease * )release;
- ( void )installWindowWillClose: ( NSNotification * )notification;

@end

NS_ASSUME_NONNULL_END

@implementation GitHubUpdater

- ( instancetype )init
{
    if( ( self = [ super init ] ) )
    {
        self.user       = @"";
        self.repository = @"";
        self.queue      = dispatch_queue_create( "com.xs-labs.GitHubUpdater", DISPATCH_QUEUE_SERIAL );
    }
    
    return self;
}

- ( void )checkForUpdatesInBackground;
{
    id< GitHubUpdaterDelegate > delegate;
    
    delegate = self.delegate;
    
    if
    (
           [ delegate respondsToSelector: @selector( updaterShouldCheckForUpdatesInBackground: ) ] == NO
        || [ delegate updaterShouldCheckForUpdatesInBackground: self ]                             == YES
    )
    {
        [ self checkForUpdatesInBackgroundWithDisplayOptions: 0 ];
    }
}

- ( IBAction )checkForUpdates: ( nullable id )sender
{
    ( void )sender;
    
    [ self checkForUpdatesInBackgroundWithDisplayOptions: GitHubUpdaterDisplayOptionsDisplayErrors | GitHubUpdaterDisplayOptionsDisplayUI ];
}

- ( void )closeProgressWindow
{
    void ( ^ close )( void );
    
    close = ^( void )
    {
        id< GitHubUpdaterDelegate > delegate;
        
        delegate = self.delegate;
        
        if( [ delegate respondsToSelector: @selector( updater:willCloseProgressWindowController: ) ] )
        {
            [ delegate updater: self willCloseProgressWindowController: self.progressWindowController ];
        }
        
        [ self.progressWindowController.window close ];
    };
    
    if( [ NSThread isMainThread ] )
    {
        close();
    }
    else
    {
        dispatch_async( dispatch_get_main_queue(), close );
    }
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
            NSAlert                   * alert;
            id< GitHubUpdaterDelegate > delegate;
            
            alert    = [ NSAlert alertWithError: error ];
            delegate = self.delegate;
            
            if( [ delegate respondsToSelector: @selector( updater:willDisplayAlert:withError: ) ] )
            {
                [ delegate updater: self willDisplayAlert: alert withError: error ];
            }
            
            [ alert runModal ];
        }
    );
}

- ( void )checkForUpdatesInBackgroundWithDisplayOptions: ( NSUInteger )options
{
    dispatch_async
    (
        dispatch_get_main_queue(),
        ^( void )
        {
            NSURL * url;
            
            if( self.checkingForUpdates )
            {
                return;
            }
            
            if( self.installWindowController != nil )
            {
                [ self.installWindowController.window makeKeyAndOrderFront: nil ];
                
                return;
            }
                
            if( self.user.length == 0 || self.repository.length == 0 )
            {
                if( options & GitHubUpdaterDisplayOptionsDisplayErrors )
                {
                    [ self displayErrorWithMessage: @"GitHub Updater not configured properly." ];
                }
                
                return;
            }
            
            self.checkingForUpdates = YES;
            url                     = [ NSURL URLWithString: [ NSString stringWithFormat: @"https://api.github.com/repos/%@/%@/releases", self.user, self.repository ] ];
            
            if( options & GitHubUpdaterDisplayOptionsDisplayUI )
            {
                {
                    void ( ^ display )( void );
                    
                    display = ^( void )
                    {
                        id< GitHubUpdaterDelegate > delegate;
                        Class                       cls;
                        
                        if( self.progressWindowController == nil )
                        {
                            delegate = self.delegate;
                            cls      = [ GitHubProgressWindowController class ];
                            
                            if( [ delegate respondsToSelector: @selector( classForUpdaterProgressWindowController: ) ] )
                            {
                                cls = [ delegate classForUpdaterProgressWindowController: self ];
                                
                                if( [ cls isKindOfClass: [ GitHubProgressWindowController class ] ] == NO )
                                {
                                    @throw [ NSException exceptionWithName: @"com.xs-labs.GitHubUpdaterException"
                                                         reason:            [ NSString stringWithFormat: @"Class %@ should inherit from %@", NSStringFromClass( cls ), [ GitHubProgressWindowController class ] ]
                                                         userInfo:          nil
                                    ];
                                }
                            }
                            
                            self.progressWindowController = [ cls new ];
                        }
                        
                        self.progressWindowController.title         = NSLocalizedString( @"Checking for Updates", @"" );
                        self.progressWindowController.message       = NSLocalizedString( @"Please wait...", @"" );
                        self.progressWindowController.indeterminate = YES;
                        self.progressWindowController.progress      = 0.0;
                        self.progressWindowController.progressMin   = 0.0;
                        self.progressWindowController.progressMax   = 0.0;
                        
                        if( [ delegate respondsToSelector: @selector( updater:willShowProgressWindowController: ) ] )
                        {
                            [ delegate updater: self willShowProgressWindowController: self.progressWindowController ];
                        }
                        
                        [ self.progressWindowController showWindow: nil ];
                        [ self.progressWindowController.window center ];
                        
                        if( [ delegate respondsToSelector: @selector( updater:didShowProgressWindowController: ) ] )
                        {
                            [ delegate updater: self didShowProgressWindowController: self.progressWindowController ];
                        }
                    };
                    
                    if( [ NSThread isMainThread ] )
                    {
                        display();
                    }
                    else
                    {
                        dispatch_sync( dispatch_get_main_queue(), display );
                    }
                }
            }
            
            dispatch_async
            (
                self.queue,
                ^( void )
                {
                    if( options & GitHubUpdaterDisplayOptionsDisplayUI )
                    {
                        [ NSThread sleepForTimeInterval: 1.0 ];
                    }
                    
                    [ self getUpdatesAtURL: url displayOptions: options ];
                }
            );
        }
    );
}

- ( void )getUpdatesAtURL: ( NSURL * )url displayOptions: ( NSUInteger )options
{
    NSURLSession         * session;
    NSURLSessionDataTask * task;
    
    session = [ NSURLSession sessionWithConfiguration: [ NSURLSessionConfiguration defaultSessionConfiguration ] ];
    task    = [ session dataTaskWithURL: url completionHandler: ^( NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error )
        {
            ( void )response;
            
            if( error )
            {
                if( options & GitHubUpdaterDisplayOptionsDisplayErrors )
                {
                    [ self displayError: error ];
                }
                
                goto end;
            }
            
            if( data.length == 0 )
            {
                if( options & GitHubUpdaterDisplayOptionsDisplayErrors )
                {
                    [ self displayErrorWithMessage: @"Failed to retrieve updates." ];
                }
                
                goto end;
            }
            
            [ self findUpdateWithData: data displayOptions: options ];
            
            end:
                
                if( options & GitHubUpdaterDisplayOptionsDisplayUI )
                {
                    [ self closeProgressWindow ];
                }
                
                dispatch_sync( dispatch_get_main_queue(), ^( void ){ self.checkingForUpdates = NO; } );
        }
    ];
    
    [ task resume ];
}

- ( void )findUpdateWithData: ( NSData * )data displayOptions: ( NSUInteger )options
{
    NSError                                       * error;
    NSArray< GitHubRelease * >                    * releases;
    Pair< GitHubRelease *, GitHubReleaseAsset * > * update;
    
    error    = nil;
    releases = [ GitHubRelease releasesWithData: data error: &error ];
    
    if( error != nil )
    {
        if( options & GitHubUpdaterDisplayOptionsDisplayErrors )
        {
            [ self displayError: error ];
        }
        
        return;
    }
    
    update = [ self findBestAssetFromReleases: releases ];
    
    if( update.first == nil || update.second == nil )
    {
        if( options & GitHubUpdaterDisplayOptionsDisplayUI )
        {
            dispatch_async
            (
                dispatch_get_main_queue(),
                ^( void )
                {
                    NSAlert                   * alert;
                    NSString                  * name;
                    NSString                  * version;
                    NSString                  * message;
                    id< GitHubUpdaterDelegate > delegate;
                    
                    alert   = [ NSAlert new ];
                    name    = [ [ NSBundle mainBundle ] objectForInfoDictionaryKey: @"CFBundleName" ];
                    version = [ [ NSBundle mainBundle ] objectForInfoDictionaryKey: @"CFBundleShortVersionString" ];
                    
                    if( name.length == 0 || version.length == 0 )
                    {
                        message = NSLocalizedString( @"You have the newest version available.", @"" );
                    }
                    else
                    {
                        message = [ NSString stringWithFormat: NSLocalizedString( @"%@ %@ is currently the newest version available.", @"" ), name, version ];
                    }
                    
                    alert.messageText     = NSLocalizedString( @"Up-to-date", @"" );
                    alert.informativeText = message;
                    
                    [ alert addButtonWithTitle: NSLocalizedString( @"OK", @"" ) ];
                    
                    if( options & GitHubUpdaterDisplayOptionsDisplayUI )
                    {
                        [ self closeProgressWindow ];
                    }
                    
                    delegate = self.delegate;
                    
                    if( [ delegate respondsToSelector: @selector( updater:willDisplayUpToDateAlert: ) ] )
                    {
                        [ delegate updater: self willDisplayUpToDateAlert: alert ];
                    }
                    
                    [ alert runModal ];
                }
            );
        }
        
        return;
    }
    
    [ self proposeToInstallAsset: update.second release: update.first ];
}

- ( Pair< GitHubRelease *, GitHubReleaseAsset * > * )findBestAssetFromReleases: ( NSArray< GitHubRelease * > * )releases
{
    NSString                                      * currentVersion;
    GitHubRelease                                 * release;
    GitHubReleaseAsset                            * asset;
    GitHubRelease                                 * bestRelease;
    GitHubReleaseAsset                            * bestAsset;
    Pair< GitHubRelease *, GitHubReleaseAsset * > * pair;
    
    asset          = nil;
    currentVersion = [ [ NSBundle mainBundle ] objectForInfoDictionaryKey: @"CFBundleShortVersionString" ];
    
    for( release in releases )
    {
        if( release.assets.count == 0 )
        {
            continue;
        }
        
        if( release.tagName.length == 0 )
        {
            continue;
        }
        
        if( [ release.tagName compare: currentVersion options: NSNumericSearch ] != NSOrderedDescending )
        {
            continue;
        }
        
        if( bestAsset != nil && ( [ release.tagName compare: bestRelease.tagName options: NSNumericSearch ] != NSOrderedDescending ) )
        {
            continue;
        }
        
        for( asset in release.assets )
        {
            if( asset.size == 0 )
            {
                continue;
            }
            
            if( asset.downloadURL == nil )
            {
                continue;
            }
            
            if( [ asset.contentType isEqualToString: @"application/x-diskcopy" ] == NO && [ asset.contentType isEqualToString: @"application/zip" ] == NO )
            {
                continue;
            }
            
            bestAsset   = asset;
            bestRelease = release;
            
            break;
        }
    }
    
    pair = [ [ Pair alloc ] initWithFirstValue: bestRelease secondValue: bestAsset ];
    
    return pair;
}

- ( void )proposeToInstallAsset: ( GitHubReleaseAsset * )asset release: ( GitHubRelease * )release
{
    dispatch_async
    (
        dispatch_get_main_queue(),
        ^( void )
        {
            id< GitHubUpdaterDelegate > delegate;
            Class                       cls;
            
            delegate = self.delegate;
            cls      = [ GitHubInstallWindowController class ];
            
            if( [ delegate respondsToSelector: @selector( classForUpdaterInstallWindowController: ) ] )
            {
                cls = [ delegate classForUpdaterInstallWindowController: self ];
                
                if( [ cls isKindOfClass: [ GitHubInstallWindowController class ] ] == NO )
                {
                    @throw [ NSException exceptionWithName: @"com.xs-labs.GitHubUpdaterException"
                                         reason:            [ NSString stringWithFormat: @"Class %@ should inherit from %@", NSStringFromClass( cls ), [ GitHubInstallWindowController class ] ]
                                         userInfo:          nil
                    ];
                }
            }
            
            self.installWindowController = [ [ cls alloc ] initWithAsset: asset release: release ];
            
            [ self bind: NSStringFromSelector( @selector( installingUpdate ) ) toObject: self.installWindowController withKeyPath: NSStringFromSelector( @selector( installingUpdate ) ) options: nil ];
            
            if( [ delegate respondsToSelector: @selector( updater:willShowInstallWindowController: ) ] )
            {
                [ delegate updater: self willShowInstallWindowController: self.installWindowController ];
            }
            
            [ self.installWindowController showWindow: nil ];
            [ self.installWindowController.window center ];
            [ [ NSNotificationCenter defaultCenter ] addObserver: self selector: @selector( installWindowWillClose: ) name: NSWindowWillCloseNotification object: self.installWindowController.window ];
            
            if( [ delegate respondsToSelector: @selector( updater:didShowInstallWindowController: ) ] )
            {
                [ delegate updater: self didShowInstallWindowController: self.installWindowController ];
            }
        }
    );
}

- ( void )installWindowWillClose: ( NSNotification * )notification;
{
    id< GitHubUpdaterDelegate > delegate;
    
    if( self.installWindowController == nil )
    {
        return;
    }
    
    if( notification.object != self.installWindowController.window )
    {
        return;
    }
    
    [ self unbind: NSStringFromSelector( @selector( installingUpdate ) ) ];
    [ [ NSNotificationCenter defaultCenter ] removeObserver: self name: NSWindowWillCloseNotification object: self.installWindowController ];
    
    delegate = self.delegate;
    
    if( [ delegate respondsToSelector: @selector( updater:willCloseInstallWindowController: ) ] )
    {
        [ delegate updater: self willCloseInstallWindowController: self.installWindowController ];
    }
    
    self.installWindowController = nil;
}

@end
