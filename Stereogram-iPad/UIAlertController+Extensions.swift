//
//  UIAlertController+Extensions.swift
//  Stereogram-iPad
//
//  Created by Patrick Wallace on 24/05/2015.
//  Copyright (c) 2015 Patrick Wallace. All rights reserved.
//

import UIKit

extension UIAlertController {

	/// Attaches a group of actions to the controller.
	///
	/// :param: actions - Array of actions to be added to the controller.
	///         The actions will be added in the order they appear in the array.

	func addActions(actions: [UIAlertAction]) {
		for action in actions {
			addAction(action)
		}
	}
}

