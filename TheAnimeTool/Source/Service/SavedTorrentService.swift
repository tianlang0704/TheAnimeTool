//
//  SavedTorrentService.swift
//  TheAnimeTool
//
//  Created by Tieria C.Monk on 10/18/16.
//  Copyright © 2016 Tieria C.Monk. All rights reserved.
//

import Foundation
import CoreData

class SavedTorrentInfo {
    var torrentName: String = ""
    var torrentSize: Float = 0
    var torrentURL: String? = nil
    var torrentId: Int = 0
    var torrentSpeed: Int? = nil
    var torrentPath: String = ""
}

class SavedTorrentService: NSObject {
    static let sharedSavedTorrentService = SavedTorrentService()
    
    let torrentController: Controller = Controller.sharedController() as! Controller
    
    var torrentCount: Int {
        get {
            return Int(torrentController.torrentsCount())
        }
    }
    
    override private init(){
        super.init()
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(HandleNewTorrentAdded), name: NotificationNewTorrentAdded, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(HandleAddTorrentFailed), name: NotificationAddNewTorrentFailed, object: nil)
    }
    
    func RegisterTorrentEntityInController(torrentEntity: Torrents){
        guard let url = torrentEntity.torrentDownloadURL else { print("Error: missing url in torrent"); return }
        self.torrentController.addTorrentFromURL(url)
    }
    
    @objc private func HandleNewTorrentAdded(notification: NSNotification){
        guard let torrent = notification.userInfo?["torrent"] as? Torrent else { print("Error: no torrent in userinfo");return }
        NSNotificationCenter.defaultCenter().postNotificationName(
            TorrentService.TorrentDidRegisterNotification,
            object: self,
            userInfo: ["torrent": torrent, "isNew": true])
    }
    
    @objc private func HandleAddTorrentFailed(notification: NSNotification){
        guard let error = notification.userInfo?["error"] as? NSError else { print("Error: no error in userinfo");return }
        NSNotificationCenter.defaultCenter().postNotificationName(TorrentService.TorrentRegisterFailedNotification, object: self, userInfo: ["error": error])
    }
}