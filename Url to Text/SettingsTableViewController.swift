//
//  SettingsTableViewController.swift
//  Url to Text
//
//  Created by Tamer Wahba on 1/30/17.
//  Copyright © 2017 Tamer Wahba. All rights reserved.
//

import UIKit

class SettingsTableViewController: UITableViewController {
    
    // MARK: - Actions
    
    @IBAction public func dismissPresented() {
        self.dismiss(animated: true, completion: nil)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row == 2 {
            guard let vc = self.parent!.presentingViewController as? ViewController else {
                return
            }
            
            vc.onboarding1()

            dismissPresented()
        }
    }
}
