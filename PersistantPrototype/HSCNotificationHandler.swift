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
    let dateFormatter: DateFormatter

    override init() {

        notificationCenter.requestAuthorization(options: [.alert, .sound]) { (granted, error) in
            // just assume it's all good
        }

        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss"

        super.init()

        notificationCenter.delegate = self

        doForceRefresh()
    }

    func displayMsg(_ msg: String) {
        NSLog(msg)
        NotificationCenter.default.post(name:Notification.Name("NewMessageNotification"), object:nil, userInfo:["msg":msg])
    }

    func doStartNewTimer(_ sender: Any, length: TimeInterval) {

        let foo = NSEntityDescription.insertNewObject(forEntityName: "Foo", into: context)
        let prospectiveDueDate = Date().addingTimeInterval(length)
        foo.setValue(prospectiveDueDate, forKey: "timestamp")
        context.performAndWait {
            do {
                try self.context.save()
            }
            catch {
                self.displayMsg("\(error)")
                return
            }
        }

        restartTimer(remainingInterval: length, taskObject: foo)
    }


    func cleanupTask(_ taskObject: NSManagedObject) {
        do {
            self.context.delete(taskObject)
            try self.context.save()
        } catch {
            displayMsg("failure deleting task object with \(error)")
        }
    }

    func restartTimer(remainingInterval: TimeInterval, taskObject: NSManagedObject) {

        let prospectiveDueDate = Date().addingTimeInterval(remainingInterval)
        let timerName = taskObject.objectID.uriRepresentation()
        displayMsg("Fire at at \(dateFormatter.string(from:prospectiveDueDate)): \(timerName)")

        let content = UNMutableNotificationContent()
        content.title = "Hestan Cue"
        content.subtitle = "Timer"
        content.body = "\(timerName) has gone off."
        content.sound = UNNotificationSound.default()
        content.userInfo = ["Foo" : taskObject.objectID.uriRepresentation().absoluteString]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: remainingInterval, repeats: false)
        let request = UNNotificationRequest(identifier: timerName.absoluteString, content: content, trigger: trigger)

        notificationCenter.add(request) { error in
            self.displayMsg("Queuing: error == \(error)")
        }
    }

    enum ResolveObjectError: Error {
        case misc(String)
    }

    func getFooForIDString(objectURIString: String) throws -> NSManagedObject {
        guard let url = URL(string: objectURIString) else {
            throw ResolveObjectError.misc("[URL error]")
        }
        var objectID: NSManagedObjectID?
        try ExceptionCatcher.catchException {
            objectID = self.context.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: url)
        }
        return try context.existingObject(with: objectID!)
    }

    func checkForDoneness(object: NSManagedObject) {

        let timerName = object.objectID.uriRepresentation()
        let fireDate = object.value(forKey: "timestamp") as! Date
        switch fireDate.compare(Date()) {
        case .orderedSame:
            displayMsg("Firing now at \(dateFormatter.string(from: Date())): \(timerName)")
            cleanupTask(object)

        case .orderedAscending:
            displayMsg("? Fired \(dateFormatter.string(from: fireDate)): \(timerName)")
            cleanupTask(object)

        case .orderedDescending:
            let remaining = fireDate.timeIntervalSince(Date())
            restartTimer(remainingInterval: remaining, taskObject: object)
        }
    }

    func didGetNotification(objectURIString: String) {

        //sleep(1000);
        do {
            let object = try self.getFooForIDString(objectURIString: objectURIString)
            checkForDoneness(object: object)
        } catch {
            displayMsg("!failing handling notif with \(error)")
        }
    }


    // MARK: - Core Data stack

    var context: NSManagedObjectContext {
        get {
            return persistentContainer.viewContext
        }
    }

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

    func doForceRefresh() {

        let fetcher: NSFetchRequest<Foo> = Foo.fetchRequest()
        do {
            fetcher.returnsObjectsAsFaults = false
            var foos: [NSManagedObject]?
            var fetchError: Error?
            self.context.performAndWait {
                do {
                    foos = try fetcher.execute()
                } catch {
                    fetchError = error
                }
            }
            if fetchError != nil {
                throw fetchError!
            }

            if foos != nil {

                if foos!.count > 0 {
                    for foo in foos! {
                        checkForDoneness(object: foo)
                    }
                } else {
                    displayMsg("no outstanding tasks")
                }
            }
        } catch {
            displayMsg("failing to get and check with \(error)")
        }
    }

    // MARK: - Notification Center delegate

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {

        completionHandler()

        if let objectURIStr = response.notification.request.content.userInfo["Foo"] as! String? {
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
        DispatchQueue.main.async {
            if let objectURIStr = notification.request.content.userInfo["Foo"] as! String? {
                self.didGetNotification(objectURIString: objectURIStr);
            }
        }
    }
}
