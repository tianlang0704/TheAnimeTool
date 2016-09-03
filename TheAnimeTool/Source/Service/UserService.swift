//
//  UserService.swift
//  TheAnimeTool
//
//  Created by Tieria C.Monk on 8/29/16.
//  Copyright © 2016 Tieria C.Monk. All rights reserved.
//

import Foundation
import CoreData

class UserService: NSObject{
    static let sharedUserService = UserService()
    static let USERNAME_KEY = "Username"
    static let USER_EXPIRE_KEY = "UserExpire"
    
    var userName: String? = nil
    var userExpire: NSDate = NSDate(timeIntervalSince1970: 0)
    
    override private init(){
        super.init()
        self.LoadUser()
    }
    
    func ClearStoredUser(){
        NSUserDefaults.standardUserDefaults().removeObjectForKey(UserService.USERNAME_KEY)
        NSUserDefaults.standardUserDefaults().removeObjectForKey(UserService.USER_EXPIRE_KEY)
    }
    
    func LoadUser(){
        let userExpire = NSUserDefaults.standardUserDefaults().doubleForKey(UserService.USER_EXPIRE_KEY)
        guard userExpire != 0 else { return }
        guard let userName = NSUserDefaults.standardUserDefaults().stringForKey(UserService.USERNAME_KEY) else { return }
        
        self.userExpire = NSDate(timeIntervalSince1970: userExpire)
        self.userName = userName
    }
    
    func StoreUser(){
        guard self.userName != nil else { return }
        guard self.userExpire.timeIntervalSince1970 != 0 else { return }
        
        NSUserDefaults.standardUserDefaults().setObject(self.userName, forKey: UserService.USERNAME_KEY)
        NSUserDefaults.standardUserDefaults().setDouble(self.userExpire.timeIntervalSince1970, forKey: UserService.USER_EXPIRE_KEY)
    }
    
    
}