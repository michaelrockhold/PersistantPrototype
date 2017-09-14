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

    lazy var notificationHandler: HSCNotificationHandler = {
        return (UIApplication.shared.delegate as! AppDelegate).notificationHandler!
    }()

    var messages: [String] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(forName:Notification.Name("NewMessageNotification"), object:nil, queue:nil, using: {  note in
            if let msg = note.userInfo?["msg"] as! String? {
                self.messages.append(msg)
                DispatchQueue.main.async {
                    self.messagesTableView.reloadData()
                    let indexPath = IndexPath(row: self.messages.count-1, section: 0)
                    self.messagesTableView.scrollToRow(at: indexPath, at: .bottom, animated: false)
                }
            }
        })

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss"

        currentTimeTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            self.currentTimeLabel.text = dateFormatter.string(from: Date())
        }
    }

    @IBAction func doStartNewShortTimer(_ sender: Any) {
        notificationHandler.doStartNewTimer(sender, length: 3)
    }

    @IBAction func doStartNewLongTimer(_ sender: Any) {
        notificationHandler.doStartNewTimer(sender, length: 30)
    }

    @IBAction func doStartNewVeryLongTimer(_ sender: Any) {
        notificationHandler.doStartNewTimer(sender, length: 90)
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
