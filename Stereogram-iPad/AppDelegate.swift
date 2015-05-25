//
//  AppDelegate.swift
//  Stereogram-iPad
//
//  Created by Patrick Wallace on 11/01/2015.
//  Copyright (c) 2015 Patrick Wallace. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

	var window: UIWindow?
	var photoStore: PhotoStore!
}

extension AppDelegate {

	/// Create a photo store using the provided URL.
	private func createPhotoStore(url: NSURL) -> ResultOf<PhotoStore> {
		var error: NSError?
		if let store = PhotoStore(rootDirectory: url, error: &error) {
			return ResultOf(store)
		}
		return .Error(error!)
	}

	/// Create view controllers using the provided photo store.
	///
	/// :param: store The photo store which the
	private func createControllers(forWindow window: UIWindow)(store: PhotoStore) ->Result {
		let photoViewController = PhotoViewController(photoStore: store)
		let navigationController = UINavigationController(rootViewController: photoViewController)

		// If photoStore is empty after creation, push a special view controller
		// which doesn't have a collection view, but instead has some welcome text.
		if store.count == 0 {
			let welcomeViewController = WelcomeViewController(photoStore: store)
			navigationController.pushViewController(welcomeViewController, animated: false)
		}

		window.rootViewController = navigationController
		window.backgroundColor = UIColor.whiteColor()
		return .Success()
	}

}

// MARK: - Delegate methods.

extension AppDelegate {

	func application(                   application: UIApplication
		, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
			// Override point for customization after application launch.

			window = UIWindow(frame: UIScreen.mainScreen().bounds)
			if let w = window {

				// Attempt to create the photo store and controllers, and return the result.
				let result = AppDelegate.createPhotoFolderURL()
					.map(createPhotoStore)
					.map0(createControllers(forWindow:w))
				switch result {
				case .Error(let error):
					let alertController = UIAlertController(title: ""
						,                                   message: error.localizedDescription
						,                            preferredStyle: UIAlertControllerStyle.Alert)
					let action = UIAlertAction(title: "Exit"
						,                        style: UIAlertActionStyle.Default) { _ in
							fatalError("Error \(error) caused this application to terminate")
					}
					alertController.addAction(action)
					w.rootViewController = alertController
				default:
					break
				}
				w.makeKeyAndVisible()
			}
			return window != nil
	}

	func applicationWillResignActive(application: UIApplication) {
		// Sent when the application is about to move from active to
		// inactive state. This can occur for certain types of temporary interruptions
		// (such as an incoming phone call or SMS message) or when the user quits the application
		// and it begins the transition to the background state.
		// Use this method to pause ongoing tasks, disable timers,
		// and throttle down OpenGL ES frame rates.
		// Games should use this method to pause the game.
	}

	func applicationDidEnterBackground(application: UIApplication) {
		NSLog("applicationDidEnterBackground:")
		//		Use this method to release shared resources, save user data, invalidate
		//		timers, and store enough application state information to restore your application
		//		to its current state in case it is terminated later.
		//		If your application supports background execution,
		//		this method is called instead of applicationWillTerminate: when the user quits.
		//
	}

	func applicationWillEnterForeground(application: UIApplication) {
		// Called as part of the transition from the background to the inactive state;
		// here you can undo many of the changes made on entering the background.
	}

	func applicationDidBecomeActive(application: UIApplication) {
		// Restart any tasks that were paused (or not yet started) while the application
		// was inactive.
		// If the application was previously in the background,
		// optionally refresh the user interface.
	}

	func applicationWillTerminate(application: UIApplication) {
		// Called when the application is about to terminate.
		// Save data if appropriate. See also applicationDidEnterBackground:.
		NSLog("applicationWillTerminate:")
	}

	/// Returns true if url exists and points to a directory.
	///
	/// :param: url - A file URL to test.
	/// :returns: True if url is a directory, False otherwise.
	private class func urlIsDirectory(url: NSURL) -> Bool {
		var isDirectory = UnsafeMutablePointer<ObjCBool>.alloc(1)
		isDirectory.initialize(ObjCBool(false))
		let fileManager = NSFileManager.defaultManager()
		if let path = url.path {
			let fileExists = fileManager.fileExistsAtPath(url.path!, isDirectory:isDirectory)
			let isDir = isDirectory.memory
			return fileExists && isDir
		}
		return false
	}

	/// Creates the global photos folder if it doesn't already exist.
	///
	/// :returns: The folder path once set up.
	///
	/// You should call this only once during setup.
	private class func createPhotoFolderURL() -> ResultOf<NSURL> {
		let fileManager = NSFileManager.defaultManager()
		let folders = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
		if let
			firstObject: String = folders[0] as? String,
			rootURL = NSURL(fileURLWithPath:firstObject, isDirectory: true) {
				let photoDir = rootURL.URLByAppendingPathComponent("Pictures")
				if urlIsDirectory(photoDir) {
					return ResultOf(photoDir)
				} else {
					// If the directory doesn't exist, then let the file manager try and create it.
					var error: NSError?
					if fileManager.createDirectoryAtURL(photoDir
						,   withIntermediateDirectories:false
						,                    attributes:nil
						,                         error:&error) {
							return ResultOf(photoDir)
					} else {
						return .Error(error!)
					}
				}
		}
		return .Error(NSError.unknownErrorWithTarget(folders
			,                                method: "[0]"
			,                                caller: "createPhotoFolderURL"))
	}

}

