//
//  DetectedURL.swift
//  Url to Text
//
//  Created by Tamer Wahba on 12/3/16.
//  Copyright © 2016 Tamer Wahba. All rights reserved.
//

import UIKit
import RealmSwift

class DetectedURL: Object {
    dynamic var detectedText = ""
    dynamic var date = Date()
    public let userEdits = List<StringObject>()
    
    convenience init(_ text: String) {
        self.init()
        detectedText = text
        userEdits.append(StringObject(text))
    }
}

class StringObject: Object {
    dynamic var value = ""
    
    convenience init (_ val: String) {
        self.init()
        value = val
    }
}
