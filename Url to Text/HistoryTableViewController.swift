//
//  HistoryTableViewController.swift
//  Url to Text
//
//  Created by Tamer Wahba on 1/21/17.
//  Copyright © 2017 Tamer Wahba. All rights reserved.
//

import UIKit

import RealmSwift

class HistoryTableViewController: UITableViewController {
    
    let realm = try! Realm()
    let history = try! Realm().objects(DetectedURL.self).sorted(byProperty: "date", ascending: false)
    var notificationToken: NotificationToken?

    var isShareModeActive = false
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.clearsSelectionOnViewWillAppear = false
        self.automaticallyAdjustsScrollViewInsets = true
        
        notificationToken = history.addNotificationBlock({ (changes: RealmCollectionChange) in
            switch changes {
            case .initial:
                self.tableView.reloadData()
            case .update(_, let deletions, let insertions, let modifications):
                self.tableView.beginUpdates()
                self.tableView.insertRows(at: insertions.map { IndexPath(row: $0, section: 0) }, with: .automatic)
                self.tableView.deleteRows(at: deletions.map { IndexPath(row: $0, section: 0) }, with: .automatic)
                self.tableView.reloadRows(at: modifications.map { IndexPath(row: $0, section: 0) }, with: .automatic)
                self.tableView.endUpdates()
            case .error(let err):
                fatalError("\(err)")
            }
        })
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return history.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "History"
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "history_cell") as! HistoryTableViewCell
        let row = indexPath.row
        let obj = history[row]
        
        cell.textField?.text = obj.userEdits.last?.value
        cell.dateLabel?.text = DateFormatter.localizedString(from: obj.date,
                                                             dateStyle: .medium,
                                                             timeStyle: .none)
        cell.index = indexPath
        cell.tableView = tableView
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if isShareModeActive {
            let activityController = UIActivityViewController(activityItems: [history[indexPath.row].userEdits.last!.value], applicationActivities: nil)
            self.present(activityController,
                         animated: true,
                         completion: nil
            )
            if let parent = self.parent as? ViewController {
                parent.finishShare()
            }
        } else {
            if let cell = tableView.cellForRow(at: indexPath) as? HistoryTableViewCell {
                cell.textField?.isEnabled = true
                cell.textField?.becomeFirstResponder()
            }

            UIView.animate(withDuration: 0.2, animations: {
                for cell in tableView.visibleCells.filter({ return ($0 as! HistoryTableViewCell).index != indexPath }) {
                    cell.contentView.alpha = 0.2
                }
            })
        }
    }
    
    override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        if let cell = tableView.cellForRow(at: indexPath) as? HistoryTableViewCell {
            cell.textField?.isEnabled = false
        }

        UIView.animate(withDuration: 0.2, animations: {
            for cell in tableView.visibleCells {
                cell.contentView.alpha = 1
            }
        })
    }
    
    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        return [
            UITableViewRowAction(style: .destructive,
                                 title: "Delete",
                                 handler: {action, index in
                                    let realm = try! Realm()
                                    let row = index.row
                                    let obj = realm.objects(DetectedURL.self).sorted(byProperty: "date", ascending: false)[row]
                                    
                                    try! realm.write {
                                        realm.delete(obj)
                                    }
            }),
            UITableViewRowAction(style: .normal,
                                 title: "Append",
                                 handler: {action, index in
                                    print("\(action) pressed on \(index)")
            }),
            UITableViewRowAction(style: .normal,
                                 title: "Copy",
                                 handler: {action, index in
                                    self.tableView.isEditing = false
                                    UIPasteboard.general.string = self.history[index.row].userEdits.last!.value
                                    if let parent = self.parent as? ViewController {
                                        parent.showMessage("Copied to clipboard")
                                    }
            }),
        ]
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
