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
    typealias CompletionHandler = () -> Void
    
    enum TorrentError: ErrorType {
        case InvalidId
        case InvalidPageData
        case InvalidTorrentCount
        case ErrorSavingCoreData
    }
    
    enum SortBy: Int {
        case Date = 1
        case Seeders
        case Leechers
        case Downloads
        case Size
        case Name
    }
    
    class TorrentInfos {
        var torrentNames: [String] = []
        var torrentSs: [Int] = []
        var torrentLs: [Int] = []
        var torrentSizes: [Float] = []
        var torrentURLs: [String?] = []
        var torrentIds: [Int?] = []
        var torrentCount: Int = 0
    }
    
    //singleton object
    static let sharedTorrentService = TorrentService()
    //notifications
    static let LocalTorrentsWillUpdateNotification = "LocalTorrentsWillUpdateNotification"
    static let LocalTorrentsDidUpdateNotification = "LocalTorrentsDidUpdateNotification"
    static let TorrentDidRegisterNotification = "TorrentDidRegisterNotification"
    static let TorrentRegisterFailedNotification = "TorrentRegisterFailedNotification"
    
    //xpaths can be changed in the settings in the future
    let TorrentEntriesXpath = "//table[@class=\"tlist\"]//tr[position()>1]"
    let TorrentNameXpath = "//table[@class=\"tlist\"]//tr[position()>1]//td[@class=\"tlistname\"]//a"
    let TorrentSXpath = "//table[@class=\"tlist\"]//tr[position()>1]//td[@class=\"tlistsn\" or @class=\"tlistfailed\"]"
    let TorrentLXpath = "//table[@class=\"tlist\"]//tr[position()>1]//td[@class=\"tlistln\" or @class=\"tlistfailed\"]"
    let TorrentSizeXpath = "//table[@class=\"tlist\"]//tr[position()>1]//td[@class=\"tlistsize\"]"
    let TorrentDownloadXpath = "//table[@class=\"tlist\"]//tr[position()>1]//td[@class=\"tlistdownload\"]//a"
    
    var insertIndexForTempEntries = 0
    
    func UpdateTempTorrentsWithSearchString(searchStr: String, page:Int = 1, sortBy: SortBy = .Date, isDesc:Bool = true){
        self.ClearTempTorrents(){
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
                    do{ try self.UpdateTempTorrentsWithNyaaHTML(data) }catch(let error){ throw error }
                }.error{ error in
                    print("Error getting torrent data: \(error)")
            }
        }
    }
    
    private func UpdateTempTorrentsWithNyaaHTML(data: NSData) throws{
        guard let html = String(data: data, encoding: NSUTF8StringEncoding) else { return }
        
        //parse nyaa search results
        let newInfos = TorrentInfos()
        let doc = NDHpple(HTMLData: html)
        newInfos.torrentNames = doc.searchWithXPathQuery(self.TorrentNameXpath).map{$0.firstChild?.content ?? ""}
        newInfos.torrentSs = doc.searchWithXPathQuery(self.TorrentSXpath).map{Int($0.firstChild?.content ?? "0") ?? 0}
        newInfos.torrentLs = doc.searchWithXPathQuery(self.TorrentLXpath).map{Int($0.firstChild?.content ?? "0") ?? 0}
        newInfos.torrentSizes = doc.searchWithXPathQuery(self.TorrentSizeXpath).map{ (item) -> Float in
            let sizeStr = item.firstChild?.content ?? "0 Mib"
            var convertionFactor: Float = 1
            convertionFactor = sizeStr.containsString("GiB") ? 1024 : convertionFactor
            convertionFactor = sizeStr.containsString("TiB") ? 1024 * 1024 : convertionFactor
            return (Float(sizeStr.substringToIndex(sizeStr.endIndex.advancedBy(-4))) ?? 0) * convertionFactor
        }
        newInfos.torrentURLs = doc.searchWithXPathQuery(self.TorrentDownloadXpath).map{ (item) -> String? in
            guard let url = item.attributes["href"] as? String else { return nil }
            guard let urlStart = url.rangeOfString("//")?.endIndex else { return url }
            return "http://\(url.substringFromIndex(urlStart))"
        }
        newInfos.torrentIds = newInfos.torrentURLs.map{ (item) -> Int? in
            guard let url = item else { return nil }
            guard let tidStart = url.rangeOfString("tid=")?.endIndex else { return nil }
            return Int(url.substringFromIndex(tidStart))
        }
        newInfos.torrentCount = newInfos.torrentNames.count
        
        self.UpdateTempTorrent(newInfos)
    }
    
    private func UpdateTempTorrent(newInfos: TorrentInfos) {
        let context = CoreDataService.sharedCoreDataService.mainQueueContext
        let fetchRequest = NSFetchRequest(namedEntity: Torrents.self)
        context.performBlock(){
            var localTorrents: [Torrents] = []
            do { localTorrents = try context.executeFetchRequest(fetchRequest) as! [Torrents] }catch(let error){print("Error getting local torrents:\(error)")}
            
            NSNotificationCenter.defaultCenter().postNotificationName(TorrentService.LocalTorrentsWillUpdateNotification, object: self)
            
            for i in 0..<newInfos.torrentCount {
                //only update some data if stored version exists
                let newTorrent: Torrents
                let nyaaId = newInfos.torrentIds[i]
                if let localTorrentIdx = localTorrents.indexOf({$0.torrentNyaaId == nyaaId}){
                    newTorrent = localTorrents[localTorrentIdx]
                }else{
                    newTorrent = NSEntityDescription.insertNewObjectForNamedEntity(Torrents.self, inManagedObjectContext: context)
                }
                newTorrent.torrentDownloadURL = newInfos.torrentURLs[i]
                newTorrent.torrentNyaaId = newInfos.torrentIds[i]
                newTorrent.torrentSize = newInfos.torrentSizes[i]
                newTorrent.torrentName = newInfos.torrentNames[i]
                newTorrent.torrentSeederCount = newInfos.torrentSs[i]
                newTorrent.torrentLeecherCount = newInfos.torrentLs[i]
                newTorrent.torrentOrder = self.insertIndexForTempEntries
                self.insertIndexForTempEntries += 1
            }
            context.SaveRecursivelyToPersistentStorageAndWait()
            NSNotificationCenter.defaultCenter().postNotificationName(TorrentService.LocalTorrentsDidUpdateNotification, object: self)
        }
    }
    
    func ClearTempTorrents(completionHandler: CompletionHandler = {}){
        let context = CoreDataService.sharedCoreDataService.mainQueueContext
        let request = NSFetchRequest(namedEntity: Torrents.self)
        context.performBlock(){
            //delete temp entries from the core data
            context.deleteAllData(request)
            context.SaveRecursivelyToPersistentStorageAndWait()  
            self.insertIndexForTempEntries = 0
            completionHandler()
        }
    }
    
    static func UtilMakeShortSearchString(string:String) -> String{
        let cleanStr = string.stringByReplacingOccurrencesOfString("\\s*\\W\\s*", withString: " ", options: NSStringCompareOptions.RegularExpressionSearch, range: nil)
        let splittedStr = cleanStr.componentsSeparatedByString(" ")
        let shortStr = String(format: "%@%@", splittedStr[0], splittedStr.count > 1 ? " \(splittedStr[1])" : "")
        return shortStr
    }
}
