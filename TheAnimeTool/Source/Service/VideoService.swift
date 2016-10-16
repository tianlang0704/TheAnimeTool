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
    typealias CompletionHandler = () -> Void
    
    typealias UpdateProgressCompletionHandler = (Float) -> Void
    typealias UpdateFilePathCompletionHandler = (String) -> Void
    
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
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(HandleTorrentDidRegister), name: TorrentService.TorrentDidRegisterNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(HandleTorrentRegisterFailed), name: TorrentService.TorrentRegisterFailedNotification, object: nil)
        TorrentService.sharedTorrentService.RegisterTorrentEntityInController(torrentEntity)
    }
    
    func ClearCurrentVideoEntities(completionHandler: CompletionHandler = {}){
        let context = CoreDataService.sharedCoreDataService.mainQueueContext
        let request = NSFetchRequest(namedEntity: Videos.self)
        context.performBlock(){
            let videoCount = context.countForFetchRequest(request, error:nil)
            if videoCount > 0 {
                context.deleteAllData(request)
            }
            context.SaveRecursivelyToPersistentStorageAndWait()
            completionHandler()
        }
    }
    
    func UpdateTempVideosWithTorrent(torrent: Torrent, isPaused: Bool = true){
        self.ClearCurrentVideoEntities(){
            let context = CoreDataService.sharedCoreDataService.mainQueueContext
            self.torrent = torrent
            self.UpdateTorrentFileInfos()
            
            context.performBlock(){
                NSNotificationCenter.defaultCenter().postNotificationName(VideoService.LocalVideosWillUpdateNotification, object: nil)
                let indexes = NSMutableIndexSet()
                let videoList = torrent.flatFileList() as! [FileListNode]
                for video in videoList {
                    let newVideoEntity = NSEntityDescription.insertNewObjectForNamedEntity(Videos.self, inManagedObjectContext: context)
                    newVideoEntity.videoName = video.name()
                    newVideoEntity.videoPath = video.path()
                    newVideoEntity.videoSize = Float(video.size() / 1024 / 1024)
                    newVideoEntity.videoIndex = Int(video.indexes().firstIndex)
                    newVideoEntity.videoDownloadPercent = Float(self.torrent?.fileProgress(video) ?? 0)
                    newVideoEntity.torrents = self.torrentEntity
                    indexes.addIndexes(video.indexes())
                }
                if(isPaused){
                    self.torrent?.setFileCheckState(FileCheckState.Off.rawValue, forIndexes: indexes)
                }
                context.SaveRecursivelyToPersistentStorageAndWait()
                NSNotificationCenter.defaultCenter().postNotificationName(VideoService.LocalVideosDidUpdateNotification, object: nil)
            }
        }
    }
    
    func GetProgressForFileIndex(index: UInt) -> Float{
        //update torrent file info in controller first
        self.UpdateTorrentFileInfos()
        return Float(self.torrent?.fileProgressFromIndex(index) ?? 0)
    }
    
    func UpdateProgressForFileIndex(index: UInt, completionHandler: UpdateProgressCompletionHandler = {progress in }){
        //update torrent file info in controller first
        self.UpdateTorrentFileInfos()
        let progress = Float(self.torrent?.fileProgressFromIndex(index) ?? 0)
        //get the video entity from core data to update info
        guard let hashString = torrent?.hashString() else { return }
        let context = CoreDataService.sharedCoreDataService.mainQueueContext
        let fetchRequest = NSFetchRequest(namedEntity: Videos.self)
        fetchRequest.predicate = NSPredicate(format: "torrents.torrentHashString == %@ AND videoIndex == %d", hashString, index)
        context.performBlock(){
            guard let videos = try? context.executeFetchRequest(fetchRequest) as! [Videos] else { return }
            guard videos.count > 0 else { return }
            videos[0].videoDownloadPercent = progress
            CoreDataService.sharedCoreDataService.SaveMainContext(){
                completionHandler(progress)
            }
        }
    }
    
    func UpdateFilePathForFileIndex(index: UInt, completionHandler: UpdateFilePathCompletionHandler = {filePath in }){
        //update torrent file info in controller first
        self.UpdateTorrentFileInfos()
        guard let filePath = torrent?.fileLocationForFileIndex(index) else { return}
        //get the video entity from core data to update info
        guard let hashString = torrent?.hashString() else { return }
        let context = CoreDataService.sharedCoreDataService.mainQueueContext
        let fetchRequest = NSFetchRequest(namedEntity: Videos.self)
        fetchRequest.predicate = NSPredicate(format: "torrents.torrentHashString == %@ AND videoIndex == %d", hashString, index)
        context.performBlock(){
            guard let videos = try? context.executeFetchRequest(fetchRequest) as! [Videos] else { return }
            videos[0].videoPath = filePath
            CoreDataService.sharedCoreDataService.SaveMainContext(){
                completionHandler(filePath)
            }
        }
    }
    
    func UpdateFilePathForFileIndexAndWait(index: UInt){
        //update torrent file info in controller first
        self.UpdateTorrentFileInfos()
        guard let filePath = torrent?.fileLocationForFileIndex(index) else { return}
        //get the video entity from core data to update info
        guard let hashString = torrent?.hashString() else { return }
        let context = CoreDataService.sharedCoreDataService.mainQueueContext
        let fetchRequest = NSFetchRequest(namedEntity: Videos.self)
        fetchRequest.predicate = NSPredicate(format: "torrents.torrentHashString == %@ AND videoIndex == %d", hashString, index)
        context.performBlockAndWait(){
            guard let videos = try? context.executeFetchRequest(fetchRequest) as! [Videos] else { return }
            videos[0].videoPath = filePath
            CoreDataService.sharedCoreDataService.SaveMainContextAndWait()
        }
    }
    
    func CheckIsDoNotDownloadForFileIndex(index: UInt) -> Bool?{
        return self.torrent?.isFileDoNotDownload(index) ?? nil
    }
    
    func SetDoNotDownloadForFileIndex(index: UInt, flag: Bool){
        self.torrent?.setFileCheckState(Int(!flag), forIndexes: NSIndexSet(index: Int(index)))
    }
    
    //return true if state changes, false when it's already started
    func StartDownloadingVideoAtIndex(index: UInt) -> Bool{
        if self.CheckIsDoNotDownloadForFileIndex(index) ?? false {
            self.SetDoNotDownloadForFileIndex(index, flag: false)
            return true
        }
        return false
    }
    
    //return true if state changes, false when it's already stopped
    func StopDownloadingVideoAtIndex(index: UInt) -> Bool{
        if !(self.CheckIsDoNotDownloadForFileIndex(index) ?? true) {
            self.SetDoNotDownloadForFileIndex(index, flag: true)
            return true
        }
        return false
    }
    
    func UpdateTorrentFileInfos(){
        torrent?.update()
        torrent?.updateFileStat()
    }
    
    
    
    @objc private func HandleTorrentDidRegister(notification: NSNotification){
        guard let torrent = notification.userInfo?["torrent"] as? Torrent else { print("Error no torrent in userinfo");return }
        guard let isNew = notification.userInfo?["isNew"] as? Bool else { print("Error no isNew flag in userinfo");return }
        if(isNew){
            self.UpdateTempVideosWithTorrent(torrent)
        }else{
            self.UpdateTempVideosWithTorrent(torrent, isPaused: false)
        }
        
    }
    
    @objc private func HandleTorrentRegisterFailed(notification: NSNotification){
        guard let error = notification.userInfo?["error"] as? NSError else { print("Error no error in userinfo");return }
        if(error.code == 1){
            guard let filePath = error.userInfo["filePath"] as? String else { print("Error no file path in userinfo"); return }
            if NSFileManager.defaultManager().fileExistsAtPath(filePath){
                do{ try NSFileManager.defaultManager().removeItemAtPath(filePath)}catch let error{ print("Error deleting duplicated torrent: \(error)") }
            }
            
            guard let hashString = error.userInfo["hashString"] as? String else { print("Error no hash in userinfo"); return }
            guard let torrent = TorrentService.sharedTorrentService.torrentController.torrentFromHash(hashString) as? Torrent else { return }
            self.UpdateTempVideosWithTorrent(torrent, isPaused: false)
        }
    }
}
