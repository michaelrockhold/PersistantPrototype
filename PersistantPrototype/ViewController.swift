//
//  ViewController.swift
//  PersistantPrototype
//
//  Created by Michael Rockhold on 9/12/17.
//  Copyright © 2017 ProtoCo. All rights reserved.
//

import UIKit

class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var messagesTableView: UITableView!
    @IBOutlet weak var currentTimeLabel: UILabel!

    var currentTimeTimer: Timer?
    lazy var dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss"
        return df
    }()

    lazy var notificationHandler: HSCNotificationHandler? = {
        return (UIApplication.shared.delegate as! AppDelegate?)?.notificationHandler!
    }()

    var messages: [String] = []

    override func awakeFromNib() {
        super.awakeFromNib()
        NotificationCenter.default.addObserver(forName:Notification.Name("NewMessageNotification"), object:nil, queue:nil, using: {  note in
            if let msg = note.userInfo?["msg"] as! String? {
                self.display(msg: msg)
            }
        })
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        currentTimeTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            self.currentTimeLabel.text = self.dateFormatter.string(from: Date())
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        messagesTableView.reloadData()
    }

    func display(msg: String) {
        self.messages.append(msg)
        DispatchQueue.main.async {
            self.messagesTableView.reloadData()
            let indexPath = IndexPath(row: self.messages.count-1, section: 0)
            self.messagesTableView.scrollToRow(at: indexPath, at: .bottom, animated: false)
        }
    }

    func displayTimerFire(_ timer: HSCTimer) {
        let timerName = timer.objectID.uriRepresentation().lastPathComponent
        self.display(msg: "Firing at \(dateFormatter.string(from: Date())): \(timerName)")
    }

    @IBAction func doStartNewShortTimer(_ sender: Any) {
        _ = notificationHandler!.doStartNewTimer(sender, interval: 3, keyPath: "viewController", selector: "displayTimerFire:")
    }

    @IBAction func doStartNewLongTimer(_ sender: Any) {
        _ = notificationHandler!.doStartNewTimer(sender, interval: 30, keyPath: "viewController", selector: "displayTimerFire:")
    }

    @IBAction func doStartNewVeryLongTimer(_ sender: Any) {
        _ = notificationHandler!.doStartNewTimer(sender, interval: 90, keyPath: "viewController", selector: "displayTimerFire:")
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "messageCell")
        cell?.textLabel?.text = messages[indexPath.row]
        return cell!
    }
}
