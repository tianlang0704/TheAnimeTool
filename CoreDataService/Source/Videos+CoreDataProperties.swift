//
//  Videos+CoreDataProperties.swift
//  FinalProject
//
//  Created by Tieria C.Monk on 8/17/16.
//
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension Videos {

    @NSManaged var videoName: String?
    @NSManaged var videoPath: String?
    @NSManaged var videoDownloadPercent: NSNumber?
    @NSManaged var videoIndex: NSNumber?
    @NSManaged var videoSize: NSNumber?
    @NSManaged var torrents: Torrents?

}
