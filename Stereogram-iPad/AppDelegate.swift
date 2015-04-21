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
    //var photoViewController = PhotoViewController()
    var photoStore: PhotoStore!

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        // Override point for customization after application launch.
        
        window = UIWindow(frame: UIScreen.mainScreen().bounds)
        
        if let w = window {
            
            // Initialise the photo store, and capture any errors it returns.
            var error: NSError?
            photoStore = PhotoStore(error: &error)
            if photoStore != nil {
                
                let photoViewController = PhotoViewController(photoStore: photoStore)
                let navigationController = UINavigationController(rootViewController: photoViewController)
                
                // If photoStore is empty after creation, push a special view controller which doesn't have a collection view, but instead has some welcome text.
                // When the user takes the first photo, pop that welcome view controller to reveal the standard collection view.
                if photoStore.count == 0 {
                    let welcomeViewController = WelcomeViewController(photoStore: photoStore)
                    navigationController.pushViewController(welcomeViewController, animated: false)
                }
                
                w.rootViewController = navigationController
                w.backgroundColor = UIColor.whiteColor()
                
            } else {
                if error == nil {
                    error = NSError(domain: ErrorDomain.PhotoStore.rawValue, code: ErrorCode.CouldntCreateSharedStore.rawValue, userInfo: [NSLocalizedDescriptionKey : "Unknown error"])
                }
                let alertController = UIAlertController(title: "", message: error!.localizedDescription, preferredStyle: UIAlertControllerStyle.Alert)
                alertController.addAction(UIAlertAction(title: "Exit", style: UIAlertActionStyle.Default) { action in
                    fatalError("Error \(error) caused this application to terminate")
                })
                w.rootViewController = alertController
            }
            w.makeKeyAndVisible()
        }
        return window != nil
    }

    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(application: UIApplication) {
        NSLog("applicationDidEnterBackground:")
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.   If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.

        // This is not currently needed, as I've switched to automatically saving as soon as stereograms are created, but I've left it commented out so I can reeable it if I do need it later on (e.g. to save preferences).
        
        
//        if let store = photoStore {
//            var bgTask = UIBackgroundTaskInvalid
//            bgTask = application.beginBackgroundTaskWithExpirationHandler {
//                // This handler is called if time runs out for the background task.
//                NSLog("Background task terminated early.")
//                application.endBackgroundTask(bgTask)
//                bgTask = UIBackgroundTaskInvalid
//            }
//            
//            // We have now created a task object with a handler to terminate it. Now create the task and run it in another thread.
//            if bgTask != UIBackgroundTaskInvalid {
//                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
//                    store.saveProperties().onError() { error in
//                        // Can't send a message to the user here. Should I store this for when the app is restarted next time?
//                        NSLog("Error saving the image property list. Error \(error), userInfo \(error.userInfo)")
//                    }
//                    NSLog("Background task complete - Property data saved.")
//                    application.endBackgroundTask(bgTask)
//                    bgTask = UIBackgroundTaskInvalid
//                }
//            }
//            else {
//                NSLog("Error: Unable to get a background task during applicationDidEnterBackground.")
//                NSLog("Changes made during the last run will not be saved.")
//            }
//        }
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        NSLog("applicationWillTerminate:")
    }


}

