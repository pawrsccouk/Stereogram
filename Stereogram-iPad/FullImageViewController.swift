//
//  FullImageViewController.swift
//  Stereogram-iPad
//
//  Created by Patrick Wallace on 16/01/2015.
//  Copyright (c) 2015 Patrick Wallace. All rights reserved.
//

import UIKit

class FullImageViewController: UIViewController {

    init(image: UIImage, forApproval: Bool) {
        super.init()
    }

    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    typealias ApprovalBlock = () -> Void
    var approvalBlock: ApprovalBlock = {}  // Function to execute when the user clicks the "Approve" button.
}
