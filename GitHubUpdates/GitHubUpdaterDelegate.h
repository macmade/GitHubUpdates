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
 * @header      GitHubUpdaterDelegate.h
 * @copyright   (c) 2017, Jean-David Gadina - www.xs-labs.com
 */

#import <Cocoa/Cocoa.h>

@class GitHubUpdater;
@class GitHubProgressWindowController;
@class GitHubInstallWindowController;

NS_ASSUME_NONNULL_BEGIN

@protocol GitHubUpdaterDelegate< NSObject >

@optional

- ( BOOL )updaterShouldCheckForUpdatesInBackground: ( GitHubUpdater * )updater;
- ( Class )classForUpdaterProgressWindowController: ( GitHubUpdater * )updater;
- ( Class )classForUpdaterInstallWindowController: ( GitHubUpdater * )updater;
- ( NSURL * )updater: ( GitHubUpdater * )updater urlForUpdatesWithUser: ( NSString * )user repository: ( NSString * )repository proposedURL: ( NSURL * )proposedURL;
- ( void )updater: ( GitHubUpdater * )updater willShowProgressWindowController: ( GitHubProgressWindowController * )controller;
- ( void )updater: ( GitHubUpdater * )updater willShowInstallWindowController: ( GitHubInstallWindowController * )controller;
- ( void )updater: ( GitHubUpdater * )updater didShowProgressWindowController: ( GitHubProgressWindowController * )controller;
- ( void )updater: ( GitHubUpdater * )updater didShowInstallWindowController: ( GitHubInstallWindowController * )controller;
- ( void )updater: ( GitHubUpdater * )updater willCloseProgressWindowController: ( GitHubProgressWindowController * )controller;
- ( void )updater: ( GitHubUpdater * )updater willCloseInstallWindowController: ( GitHubInstallWindowController * )controller;
- ( void )updater: ( GitHubUpdater * )updater willDisplayAlert: ( NSAlert * )alert withError: ( NSError * )error;
- ( void )updater: ( GitHubUpdater * )updater willDisplayUpToDateAlert: ( NSAlert * )alert;

@end

NS_ASSUME_NONNULL_END
