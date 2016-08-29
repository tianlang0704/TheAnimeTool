//
//  Users+CoreDataProperties.swift
//  FinalProject
//
//  Created by Tieria C.Monk on 8/9/16.
//
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension Users {

    @NSManaged var userName: String?
    @NSManaged var torrents: NSSet?

}
