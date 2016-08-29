//
//  VideoService.swift
//  FinalProject
//
//  Created by Tieria C.Monk on 8/17/16.
//
//

import Foundation
import CoreData

public class VideoService: NSObject {
    enum VideoError: ErrorType{
        case InvalidIndex
    }
    enum FileCheckState: Int{
        case On = 1
        case Off = 0
        case Mixed = -1
    }
    static let LocalVideosDidUpdateNotification = "LocalVideosDidUpdateNotification"
    static let LocalVideosWillUpdateNotification = "LocalVideosWillUpdateNotification"
    
    let torrentEntity: Torrents
    var torrent: Torrent? = nil
    
    init(torrentEntity: Torrents){
        self.torrentEntity = torrentEntity
        super.init()
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(HandleTorrentInControllerDidUpdate), name: TorrentService.TorrentInControllerDidUpdateNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(HandleTorrentInControllerUpdateFailed), name: TorrentService.TorrentInControllerUpdateFailedNotification, object: nil)
    }
    
    func UpdateLocalVideo(){
        TorrentService.sharedTorrentService.UpdateTorrentEntityInController(torrentEntity)
    }
    
    func ClearCurrentTorrentEntityAndVideos(){
        let context = CoreDataService.sharedCoreDataService.mainQueueContext
        let request = NSFetchRequest(namedEntity: Videos.self)
        let videoCount = context.countForFetchRequest(request, error:nil)
        if videoCount > 0 {
            context.deleteAllData(request)
        }
        
        if let hashString = self.torrentEntity.torrentHashString{
            if self.torrentEntity.torrentFlagTemp! ?? false == true {
                TorrentService.sharedTorrentService.torrentController.removeTorrentsWithHashs([hashString], trashData: true)
                torrentEntity.torrentHashString = nil
                do{try context.save()} catch(let error){ print("Error clearing torrent data: \(error)") }
            }
        }
    }
    
    func UpdateLocalVideosWithTorrent(torrent: Torrent){
        let context = CoreDataService.sharedCoreDataService.mainQueueContext
        self.torrentEntity.torrentHashString = torrent.hashString()
        self.torrent = torrent
        //self.torrent?.stopTransfer()
        
        NSNotificationCenter.defaultCenter().postNotificationName(VideoService.LocalVideosWillUpdateNotification, object: nil)
        let indexes = NSMutableIndexSet()
        let videoList = torrent.flatFileList() as! [FileListNode]
        for video in videoList {
            let newVideoEntity = NSEntityDescription.insertNewObjectForNamedEntity(Videos.self, inManagedObjectContext: context)
            newVideoEntity.videoName = video.name()
            newVideoEntity.videoPath = video.path()
            newVideoEntity.videoSize = Float(video.size() / 1024 / 1024)
            newVideoEntity.videoIndex = Int(video.indexes().firstIndex)
            newVideoEntity.torrents = torrentEntity
            indexes.addIndexes(video.indexes())
        }
        self.torrent?.setFileCheckState(FileCheckState.Off.rawValue, forIndexes: indexes)
        do{try context.save()}catch(let error){print("Error updating local videos: \(error)"); return}
        NSNotificationCenter.defaultCenter().postNotificationName(VideoService.LocalVideosDidUpdateNotification, object: nil)
    }
    
    func UpdateProgressForFileIndex(index: UInt) -> Float{
        //update torrent file info in controller first
        self.UpdateTorrentFileInfos()
        let progress = Float(torrent?.fileProgressFromIndex(index) ?? 0)
        //get the video entity from core data to update info
        guard let hashString = torrent?.hashString() else { return progress }
        let context = CoreDataService.sharedCoreDataService.mainQueueContext
        let fetchRequest = NSFetchRequest(namedEntity: Videos.self)
        fetchRequest.predicate = NSPredicate(format: "torrents.torrentHashString == %@ AND videoIndex == %d", hashString, index)
        guard let videos = try? context.executeFetchRequest(fetchRequest) as! [Videos] else { return progress }
        guard videos.count > 0 else { return progress }
        videos[0].videoDownloadPercent = progress
        do{ try context.save()}catch(let error){print("Error saving video progress:\(error)") }
        //return the updated info
        return progress
    }
    
    func UpdateFilePathForFileIndex(index: UInt) -> String{
        //update torrent file info in controller first
        self.UpdateTorrentFileInfos()
        guard let filePath = torrent?.fileLocationForFileIndex(index) else { return "" }
        //get the video entity from core data to update info
        guard let hashString = torrent?.hashString() else { return filePath }
        let context = CoreDataService.sharedCoreDataService.mainQueueContext
        let fetchRequest = NSFetchRequest(namedEntity: Videos.self)
        fetchRequest.predicate = NSPredicate(format: "torrents.torrentHashString == %@ AND videoIndex == %d", hashString, index)
        guard let videos = try? context.executeFetchRequest(fetchRequest) as! [Videos] else { return filePath }
        guard videos.count > 0 else { return filePath }
        videos[0].videoPath = filePath
        do{ try context.save()}catch(let error){print("Error saving video progress:\(error)") }
        //return the updated info
        return filePath
    }
    
    func CheckIsDoNotDownloadForFileIndex(index: UInt) -> Bool?{
        return self.torrent?.isFileDoNotDownload(index) ?? nil
    }
    
    func SetDoNotDownloadForFileIndex(index: UInt, flag: Bool){
        self.torrent?.setFileCheckState(Int(!flag), forIndexes: NSIndexSet(index: Int(index)))
    }
    
    func UpdateTorrentFileInfos(){
        torrent?.update()
        torrent?.updateFileStat()
    }
    
    @objc private func HandleTorrentInControllerDidUpdate(notification: NSNotification){
        guard let torrent = notification.userInfo?["torrent"] as? Torrent else { print("Error no torrent in userinfo");return }
        self.ClearCurrentTorrentEntityAndVideos()
        self.UpdateLocalVideosWithTorrent(torrent)
    }
    
    @objc private func HandleTorrentInControllerUpdateFailed(notification: NSNotification){
        guard let error = notification.userInfo?["error"] as? NSError else { print("Error no error in userinfo");return }
        if(error.code == 1){
            guard let hashString = error.userInfo["hashString"] as? String else { print("Error no hash in userinfo");return }
            guard let torrent = TorrentService.sharedTorrentService.torrentController.torrentFromHash(hashString) as? Torrent else { return }
            self.ClearCurrentTorrentEntityAndVideos()
            self.UpdateLocalVideosWithTorrent(torrent)
        }
    }
}
