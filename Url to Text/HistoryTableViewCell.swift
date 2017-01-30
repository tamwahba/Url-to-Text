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
    @IBOutlet var dateLabel: UILabel?
    public var index: IndexPath?
    public var tableView: UITableView?

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
    override func prepareForReuse() {
        self.textField?.isEnabled = false
        self.contentView.alpha = 1
    }
    
    // Mark: - UITextFieldDelegate
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        
        let realm = try! Realm()
        let obj = realm.objects(DetectedURL.self).sorted(byProperty: "date", ascending: false)[index!.row]
        
        if obj.userEdits.last?.value != textField.text {
            try! realm.write {
                obj.userEdits.append(StringObject(textField.text!))
            }
        }
        
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        tableView?.delegate?.tableView!(tableView!, didDeselectRowAt: index!)
        tableView?.deselectRow(at: index!, animated: true)
    }

}
