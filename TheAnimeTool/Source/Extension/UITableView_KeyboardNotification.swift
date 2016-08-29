//
//  UITableView_KeyboardNotification.swift
//  Assignment4
//
//  Created by Charles Augustine on 7/10/15.
//
//


import UIKit


extension UITableView {
	func adjustInsetsForWillShowKeyboardNotification(notification: NSNotification) {
		if let userInfo = notification.userInfo as? Dictionary<String, AnyObject>, let rectValue = (userInfo[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.CGRectValue(), let convertedRect = self.superview?.convertRect(rectValue, fromView: nil), let animationDuration = (userInfo[UIKeyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue {
			UIView.animateWithDuration(animationDuration, animations: { () -> Void in
				var contentInset = self.contentInset
				contentInset.bottom = CGRectGetHeight(convertedRect)
				self.contentInset = contentInset
				self.scrollIndicatorInsets = contentInset
			})
		}
	}

	func adjustInsetsForWillHideKeyboardNotification(notification: NSNotification) {
		if let userInfo = notification.userInfo as? Dictionary<String, AnyObject>, let animationDuration = (userInfo[UIKeyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue {
			UIView.animateWithDuration(animationDuration, animations: { () -> Void in
				var contentInset = self.contentInset
				contentInset.bottom = 0.0
				self.contentInset = contentInset
				self.scrollIndicatorInsets = contentInset
			})
		}
	}
}
