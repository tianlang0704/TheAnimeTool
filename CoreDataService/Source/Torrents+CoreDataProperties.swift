//
//  Torrents+CoreDataProperties.swift
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

extension Torrents {

    @NSManaged var torrentDownloads: NSNumber?
    @NSManaged var torrentFlagTemp: NSNumber?
    @NSManaged var torrentLeechers: NSNumber?
    @NSManaged var torrentLocalPath: String?
    @NSManaged var torrentName: String?
    @NSManaged var torrentNyaaId: NSNumber?
    @NSManaged var torrentSeeders: NSNumber?
    @NSManaged var torrentSize: NSNumber?
    @NSManaged var torrentHashString: String?
    @NSManaged var torrentOrder: NSNumber?
    @NSManaged var torrentDownloadURL: String?
    @NSManaged var animes: Animes?
    @NSManaged var users: NSSet?
    @NSManaged var videos: NSSet?

}
