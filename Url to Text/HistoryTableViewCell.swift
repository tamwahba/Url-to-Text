//
//  HistoryTableViewCell.swift
//  Url to Text
//
//  Created by Tamer Wahba on 12/4/16.
//  Copyright © 2016 Tamer Wahba. All rights reserved.
//

import UIKit

import RealmSwift

class HistoryTableViewCell: UITableViewCell, UITextFieldDelegate {
    
    @IBOutlet var textField: UITextField?
    public var index: IndexPath?
    public var tableView: UITableView?

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if index!.row > 2 {
            let targetRow = index!.row - 3
            tableView!.scrollToRow(at: IndexPath(row: targetRow, section: index!.section), at: .top, animated: true)
        } else {
            tableView!.scrollToRow(at: index!, at: .none, animated: true)
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        
        let realm = try! Realm()
        
        if realm.objects(DetectedURL.self)[index!.row].userEdits.last?.value != textField.text {
            try! realm.write {
                let row = realm.objects(DetectedURL.self).count - index!.row - 1
                realm.objects(DetectedURL.self)[row].userEdits.append(StringObject(textField.text!))
            }
        }
        
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        print("ended")
    }

}
