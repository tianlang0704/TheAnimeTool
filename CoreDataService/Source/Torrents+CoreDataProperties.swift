//
//  Torrents+CoreDataProperties.swift
//  TheAnimeTool
//
//  Created by Tieria C.Monk on 10/14/16.
//  Copyright © 2016 Tieria C.Monk. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension Torrents {

    @NSManaged var torrentDownloadURL: String?
    @NSManaged var torrentLeecherCount: NSNumber?
    @NSManaged var torrentName: String?
    @NSManaged var torrentNyaaId: NSNumber?
    @NSManaged var torrentSeederCount: NSNumber?
    @NSManaged var torrentSize: NSNumber?
    @NSManaged var torrentOrder: NSNumber?
    @NSManaged var animes: Animes?
    @NSManaged var users: NSSet?
    @NSManaged var videos: NSSet?

}
