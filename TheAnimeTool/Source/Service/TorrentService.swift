//
//  TorrentService.swift
//  FinalProject
//
//  Created by Tieria C.Monk on 8/13/16.
//
//

import Foundation
import CoreData
import PromiseKit
import NDHpple

public class TorrentService: NSObject {
    enum TorrentError: ErrorType{
        case InvalidId
        case InvalidPageData
        case InvalidTorrentCount
        case ErrorSavingCoreData
    }
    
    enum SortBy: Int{
        case Date = 1
        case Seeders
        case Leechers
        case Downloads
        case Size
        case Name
    }
    
    //singleton object
    static let sharedTorrentService = TorrentService()
    //notifications
    static let LocalTorrentsWillUpdateNotification = "LocalTorrentsWillUpdateNotification"
    static let LocalTorrentsDidUpdateNotification = "LocalTorrentsDidUpdateNotification"
    static let TorrentInControllerDidUpdateNotification = "TorrentInControllerDidUpdateNotification"
    static let TorrentInControllerUpdateFailedNotification = "TorrentInControllerUpdateFailedNotification"
    
    //xpaths can be changed in the settings in the future
    let TorrentEntriesXpath = "//table[@class=\"tlist\"]//tr[position()>1]"
    let TorrentNameXpath = "//table[@class=\"tlist\"]//tr[position()>1]//td[@class=\"tlistname\"]//a"
    let TorrentSXpath = "//table[@class=\"tlist\"]//tr[position()>1]//td[@class=\"tlistsn\" or @class=\"tlistfailed\"]"
    let TorrentLXpath = "//table[@class=\"tlist\"]//tr[position()>1]//td[@class=\"tlistln\" or @class=\"tlistfailed\"]"
    let TorrentDXpath = "//table[@class=\"tlist\"]//tr[position()>1]//td[@class=\"tlistdn\"]"
    let TorrentSizeXpath = "//table[@class=\"tlist\"]//tr[position()>1]//td[@class=\"tlistsize\"]"
    let TorrentDownloadXpath = "//table[@class=\"tlist\"]//tr[position()>1]//td[@class=\"tlistdownload\"]//a"
    //torrent engine
    let torrentController: Controller
    
    var insertIndexForTempEntries = 0
    
    override init() {
        torrentController = Controller.sharedController() as! Controller
        torrentController.fixDocumentsDirectory()
        torrentController.transmissionInitialize()
        super.init()
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(HandleNewTorrentAdded), name: NotificationNewTorrentAdded, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(HandleAddTorrentFailed), name: NotificationAddNewTorrentFailed, object: nil)
    }
    
    func GetTorrentEntitiesFromHash(hashString: String) -> [Torrents]{
        let fetchRequest = NSFetchRequest(namedEntity: Torrents.self)
        fetchRequest.predicate = NSPredicate(format: "torrentHashString == %@", hashString)
        var res:[Torrents] = []
        do{
            res = try CoreDataService.sharedCoreDataService.mainQueueContext.executeFetchRequest(fetchRequest) as! [Torrents]
        }catch(let error){
            print("Error finding torrents from hash string: \(error)")
        }
        return res
    }
    
    func UpdateTempTorrentsWith(searchStr: String, page:Int = 1, sortBy: SortBy = .Date, isDesc:Bool = true){
        self.ClearTempTorrents()
        firstly{ () -> URLDataPromise in
            return NSURLSession.GET("http://www.nyaa.se/",
                query: ["page":"search",
                "cats":"1_0",
                "filter":"0",
                "term":searchStr,
                "sort":sortBy.rawValue,
                "order":(isDesc ? 1 : 2),
                "offset":page])
            }.then{ data -> Void in
                do{ try self.UpdateLocalTorrents(data, isTemp: true) }catch(let error){ throw error }
            }.error{ error in
                print("Error getting torrent data: \(error)")
        }
    }
    
    private func UpdateLocalTorrents(data: NSData, isTemp: Bool) throws{
        guard let html = String(data: data, encoding: NSUTF8StringEncoding) else { return }
        let doc = NDHpple(HTMLData: html)
        let torrentNames = doc.searchWithXPathQuery(self.TorrentNameXpath).map{$0.firstChild?.content}
        let torrentS = doc.searchWithXPathQuery(self.TorrentSXpath).map{Int($0.firstChild?.content ?? "0") ?? 0}
        let torrentL = doc.searchWithXPathQuery(self.TorrentLXpath).map{Int($0.firstChild?.content ?? "0") ?? 0}
        let torrentD = doc.searchWithXPathQuery(self.TorrentDXpath).map{Int($0.firstChild?.content ?? "0") ?? 0}
        let torrentSize = doc.searchWithXPathQuery(self.TorrentSizeXpath).map{ (item) -> Float in
            let sizeStr = item.firstChild?.content ?? "0 Mib"
            return Float(sizeStr.substringToIndex(sizeStr.endIndex.advancedBy(-4))) ?? 0
        }
        let torrentURL = doc.searchWithXPathQuery(self.TorrentDownloadXpath).map{ (item) -> String? in
            guard let url = item.attributes["href"] as? String else { return nil }
            guard let urlStart = url.rangeOfString("//")?.endIndex else { return url }
            return "http://\(url.substringFromIndex(urlStart))"
        }
        let torrentIds = torrentURL.map{ (item) -> Int? in
            guard let url = item else { return nil }
            guard let tidStart = url.rangeOfString("tid=")?.endIndex else { return nil }
            return Int(url.substringFromIndex(tidStart))
        }
        
        NSNotificationCenter.defaultCenter().postNotificationName(TorrentService.LocalTorrentsWillUpdateNotification, object: self)

        let context = CoreDataService.sharedCoreDataService.mainQueueContext
        let torrentCount = torrentNames.count
        for i in 0..<torrentCount {
            let newTorrent = NSEntityDescription.insertNewObjectForNamedEntity(Torrents.self, inManagedObjectContext: context)
            newTorrent.torrentName = torrentNames[i]
            newTorrent.torrentNyaaId = torrentIds[i]
            newTorrent.torrentSeeders = torrentS[i]
            newTorrent.torrentLeechers = torrentL[i]
            newTorrent.torrentDownloads = torrentD[i]
            newTorrent.torrentSize = torrentSize[i]
            newTorrent.torrentDownloadURL = torrentURL[i]
            newTorrent.torrentFlagTemp = NSNumber(bool: isTemp)
            newTorrent.torrentOrder = self.insertIndexForTempEntries
            self.insertIndexForTempEntries += 1
        }
        
        do{ try context.save()} catch {
            print("Error saving new torrent information")
            throw TorrentError.ErrorSavingCoreData
        }
        
        NSNotificationCenter.defaultCenter().postNotificationName(TorrentService.LocalTorrentsDidUpdateNotification, object: self)
    }
    
    func UpdateTorrentEntityInController(torrentEntity: Torrents){
        let torrentController = TorrentService.sharedTorrentService.torrentController
        
        if let hashString = torrentEntity.torrentHashString {
            if let torrent = torrentController.torrentFromHash(hashString) as? Torrent {
                NSNotificationCenter.defaultCenter().postNotificationName(TorrentService.TorrentInControllerDidUpdateNotification, object: self, userInfo: ["torrent": torrent])
                return
            }else{
                torrentEntity.torrentHashString = nil
                do{ try CoreDataService.sharedCoreDataService.mainQueueContext.save()}catch{print("Error reset hash failed")}
            }
        }
        
        guard let url = torrentEntity.torrentDownloadURL else { return }
        torrentController.addTorrentFromURL(url)
    }
    
    @objc private func HandleNewTorrentAdded(notification: NSNotification){
        guard let torrent = notification.userInfo?["torrent"] as? Torrent else { print("Error no torrent in userinfo");return }
        NSNotificationCenter.defaultCenter().postNotificationName(TorrentService.TorrentInControllerDidUpdateNotification, object: self, userInfo: ["torrent": torrent])
    }
    
    @objc private func HandleAddTorrentFailed(notification: NSNotification){
        guard let error = notification.userInfo?["error"] as? NSError else { print("Error no error in userinfo");return }
        NSNotificationCenter.defaultCenter().postNotificationName(TorrentService.TorrentInControllerUpdateFailedNotification, object: self, userInfo: ["error": error])
    }
    
    func ClearTempTorrents(){
        if self.insertIndexForTempEntries > 0{
            let context = CoreDataService.sharedCoreDataService.mainQueueContext
            let request = NSFetchRequest(namedEntity: Torrents.self)
            request.predicate = NSPredicate(format: "torrentFlagTemp == YES")
            context.deleteAllData(request)
            self.insertIndexForTempEntries = 0
        }
    }
    
    static func UtilMakeShortSearchString(string:String) -> String{
        let cleanStr = string.stringByReplacingOccurrencesOfString("\\s*\\W\\s*", withString: " ", options: NSStringCompareOptions.RegularExpressionSearch, range: nil)
        let splittedStr = cleanStr.componentsSeparatedByString(" ")
        let shortStr = String(format: "%@%@", splittedStr[0], splittedStr.count > 1 ? " \(splittedStr[1])" : "")
        return shortStr
    }
}
