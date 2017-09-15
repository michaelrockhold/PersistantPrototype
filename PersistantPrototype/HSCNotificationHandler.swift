//
//  HSCNotificationHandler.swift
//  PersistantPrototype
//
//  Created by Michael Rockhold on 9/13/17.
//  Copyright © 2017 ProtoCo. All rights reserved.
//

import UIKit
import CoreData
import UserNotifications

class HSCNotificationHandler: NSObject, UNUserNotificationCenterDelegate {

    let notificationCenter = UNUserNotificationCenter.current()
    let targetRoot: NSObject
    let dateFormatter: DateFormatter

    init(targetRoot: NSObject) {

        self.targetRoot = targetRoot

        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss"

        super.init()

        notificationCenter.requestAuthorization(options: [.alert, .sound]) { (granted, error) in
            // just assume it's all good
        }

        notificationCenter.delegate = self

        doForceRefresh()
    }

    func displayMsg(_ msg: String) {
        NSLog(msg)
        NotificationCenter.default.post(name:Notification.Name("NewMessageNotification"), object:nil, userInfo:["msg":msg])
    }

    func makeNewTimer(fireDate: Date, keyPath: String, selector: String) throws -> HSCTimer {

        var returnTimer: HSCTimer? = nil

        try self.doInContext { (context, coordinator) in
            let timer = NSEntityDescription.insertNewObject(forEntityName: "HSCTimer", into: context) as! HSCTimer
            timer.fireDate = fireDate as NSDate
            timer.keyPath = keyPath
            timer.selector = selector
            try context.save()
            returnTimer = timer
        }

        return returnTimer!
    }

    func doStartNewTimer(_ sender: Any, length: TimeInterval, keyPath: String, selector: String) {

        do {
            let timer = try makeNewTimer(fireDate: Date().addingTimeInterval(length), keyPath: keyPath, selector: selector)
            restartTimer(remainingInterval: length, timer: timer)
        }
        catch {
            self.displayMsg("\(error)")
        }
    }

    func fire(timer: HSCTimer, late: Bool = false) {
        if let target = targetRoot.value(forKeyPath: timer.keyPath!) as! NSObject? {
            target.perform(Selector(timer.selector!), with: timer)
        }

        cleanupTask(timer)
    }


    func cleanupTask(_ timer: HSCTimer) {
        do {
            try self.doInContext { (context, coordinator) in
                context.delete(timer)
                try context.save()
            }
        } catch {
            displayMsg("failure deleting task object with \(error)")
        }
    }

    func restartTimer(remainingInterval: TimeInterval, timer: HSCTimer) {

        let prospectiveDueDate = Date().addingTimeInterval(remainingInterval)
        let timerName = timer.objectID.uriRepresentation()
        displayMsg("Fire at at \(dateFormatter.string(from:prospectiveDueDate)): \(timerName.lastPathComponent)")

        let content = UNMutableNotificationContent()
        content.title = "Hestan Cue"
        content.subtitle = "Timer"
        content.body = "\(timerName) has gone off."
        content.sound = UNNotificationSound.default()
        content.userInfo = ["URI" : timer.objectID.uriRepresentation().absoluteString]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: remainingInterval, repeats: false)
        let request = UNNotificationRequest(identifier: timerName.absoluteString, content: content, trigger: trigger)

        notificationCenter.add(request, withCompletionHandler: nil)
    }

    enum ResolveObjectError: Error {
        case misc(String)
    }

    func getTimerForIDString(objectURIString: String) throws -> HSCTimer {

        guard let url = URL(string: objectURIString) else {
            throw ResolveObjectError.misc("ID string is not a URI")
        }

        var timer: HSCTimer? = nil
        try self.doInContext { (context, coordinator) in
            var objectID: NSManagedObjectID? = nil
            try ExceptionCatcher.catchException {
                objectID = coordinator.managedObjectID(forURIRepresentation: url)
            }
            timer = try context.existingObject(with: objectID!) as? HSCTimer
        }
        return timer!
    }

    func checkForDoneness(timer: HSCTimer) {

        let fireDate = timer.fireDate! as Date
        switch fireDate.compare(Date()) {

        case .orderedSame:
            fire(timer: timer)

        case .orderedAscending:
            fire(timer: timer, late: true)

        case .orderedDescending:
            restartTimer(remainingInterval: fireDate.timeIntervalSince(Date()), timer: timer)
        }
    }

    func didGetNotification(objectURIString: String) {

        do {
            let timer = try self.getTimerForIDString(objectURIString: objectURIString)
            checkForDoneness(timer: timer)
        } catch {
            displayMsg("!failing handling notif with \(error)")
        }
    }


    // MARK: - Core Data stack

    lazy var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
         */
        let container = NSPersistentContainer(name: "PersistantPrototype")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("!Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()

    // MARK: - Core Data Saving support

    func saveContext () {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                fatalError("!Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }

    func doInContext(_ block: @escaping (_ context: NSManagedObjectContext, _ coordinator: NSPersistentStoreCoordinator) throws -> Void) throws {
        var blockError: Error? = nil
        persistentContainer.viewContext.performAndWait {
            do {
                try block(self.persistentContainer.viewContext, self.persistentContainer.persistentStoreCoordinator)
            } catch {
                blockError = error
            }
        }
        if blockError != nil {
            throw blockError!
        }
    }

    func doForceRefresh() {

        do {
            try self.doInContext { (context, coordinator) in
                let fetcher: NSFetchRequest<HSCTimer> = HSCTimer.fetchRequest()
                fetcher.returnsObjectsAsFaults = false

                let timers = try fetcher.execute() as [HSCTimer]?
                if timers != nil && timers!.count > 0 {
                    for timer in timers! {
                        self.checkForDoneness(timer: timer)
                    }
                } else {
                    self.displayMsg("no outstanding tasks")
                }
            }
        } catch {
            self.displayMsg("error fetching: \(error)")
        }
    }

    // MARK: - Notification Center delegate

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {

        // This is the method called if the app was not frontmost when the local notification was triggered.

        completionHandler()

        if let objectURIStr = response.notification.request.content.userInfo["URI"] as! String? {
            didGetNotification(objectURIString: objectURIStr);
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {

        // This is the method called if the app is frontmost when the local notification is triggered.

        // here you might do something like check to see what app-specific kind of notification this is, and
        // perhaps restore the user experience to something appropriate to that kind. You might call the completion
        // handler with different options depending on what kind it is.

        completionHandler([])
        
        if let objectURIStr = notification.request.content.userInfo["URI"] as! String? {
            didGetNotification(objectURIString: objectURIStr);
        }
    }
}
