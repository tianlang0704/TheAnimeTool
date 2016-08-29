//
//  AnimeService.swift
//  FinalProject
//
//  Created by Tieria C.Monk on 8/11/16.
//
//

import UIKit
import PromiseKit
import SwiftyJSON
import CoreData

public class AnimeService: NSObject {
    enum AnimeError: ErrorType{
        case InvalidToken
        case InvalidIconURL
        case InvalidServerJSONArray
        case ErrorSavingCoreData
        case EmtpyResult
    }
    
    static let LocalAnimeWillUpdateNotification = "LocalAnimeWillUpdateNotification"
    static let LocalAnimeDidUpdateNotification = "LocalAnimeDidUpdateNotification"
    static let LocalAnimeUpdateFailedNotification = "LocalAnimeUpdateFailedNotification"
    
    var tokenString: String? = nil
    var tokenExpire: NSDate = NSDate(timeIntervalSince1970: 0)
    var insertIndexForTempEntries = 0
    
    func UpdateTempWithAiringAnimes(){
        self.ClearTempAnimes()
        //Update anilist API token first, then get updated data on airing animes
        UpdateTokenIfNeeded(){ service in
            firstly{
                return NSURLSession.GET("https://anilist.co/api/browse/anime",
                    query: ["access_token": "\(service.tokenString!)",
                    "status": "Currently Airing",
                    "type": "Tv",
                    "full_page": "true",
                    "airing_data": "true"])
            }.then{ data -> Void in
                let animeJSON = JSON(data: data)
                do{ try self.UpdateLocalAnimes(animeJSON, isTemp: true) } catch(let error){ throw error }
            }.error{ error in
                NSNotificationCenter.defaultCenter().postNotificationName(AnimeService.LocalAnimeUpdateFailedNotification, object: error as NSError)
                print("Error getting anime data: \(error)")
            }
        }
    }
    
    func UpdateTempAnimesWithSearchString(searchStr: String){
        self.ClearTempAnimes()
        //Update anilist API token first, then search for anime
        UpdateTokenIfNeeded(){ service in
            firstly{
                return NSURLSession.GET("https://anilist.co/api/anime/search/\(searchStr.stringByReplacingOccurrencesOfString(" ", withString: "+"))",
                    query: ["access_token": "\(service.tokenString!)"])
                }.then{ data -> Void in
                    let animeJSON = JSON(data: data)
                    do{ try self.UpdateLocalAnimes(animeJSON, isTemp: true) } catch(let error){ throw error }
                }.error{ error in
                    NSNotificationCenter.defaultCenter().postNotificationName(AnimeService.LocalAnimeUpdateFailedNotification, object: error as NSError)
                    print("Error getting anime data: \(error)")
            }
        }
    }
    
    //Update the anilist API token and store it
    private func UpdateTokenIfNeeded(callback: (animeService: AnimeService) -> Void){
        firstly{ () -> URLDataPromise in
            //only update API token when it's expired
            let date = NSDate()
            if date.compare(tokenExpire) == NSComparisonResult.OrderedDescending {
                return NSURLSession.POST("https://anilist.co/api/auth/access_token",
                    formData: ["grant_type": "client_credentials",
                        "client_id": "tianlang0704-of3vo",
                        "client_secret": "YdmxkUXtzmM2J4JGeRqPee4"])
            }else{
                let dataJSON = String(format:"{\"access_token\":\"%@\"}", tokenString!).dataUsingEncoding(NSUTF8StringEncoding)!
                return URLDataPromise.go(NSURLRequest(URL: NSURL(string: "http://dummy.co")!)) { completionHandler in
                    completionHandler(dataJSON, nil, nil)
                }
            }
        }.then{ data -> Void in
            let dataJSON = JSON(data: data)
            guard let tokenString = dataJSON["access_token"].string else { throw AnimeError.InvalidToken }
            if let tokenExpire = dataJSON["expires_in"].int {
                self.tokenExpire = NSDate(timeIntervalSinceNow: Double(tokenExpire - 10))
                self.tokenString = tokenString
            }
            print(tokenString)
            print(self.tokenExpire)
            callback(animeService: self)
        }
    }
    
    //Update local anime data from the JSON array of anilist small model
    private func UpdateLocalAnimes(JSONObject: JSON, isTemp: Bool) throws{
        if let errorCdoe = JSONObject["error"]["status"].int{
            if errorCdoe == 200{
                throw AnimeError.EmtpyResult
            }
        }
        
        guard let animesJSONArray = JSONObject.array else { throw AnimeError.InvalidServerJSONArray }
        let context = CoreDataService.sharedCoreDataService.mainQueueContext
        let fetchRequest = NSFetchRequest(namedEntity: Animes.self)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "animeAnilistId", ascending: true)]
        fetchRequest.predicate = NSPredicate(format: "animeStatus == %@", "currently airing")
        guard let fetchedAnimes = try? context.executeFetchRequest(fetchRequest) as? [Animes] ?? [] else { return }
        
        NSNotificationCenter.defaultCenter().postNotificationName(AnimeService.LocalAnimeWillUpdateNotification, object: self)
        
        for animeJSON in animesJSONArray{
            print(animeJSON.description)
            
            var targetAnime: Animes
            if let found = fetchedAnimes.map({$0.animeAnilistId as! Int}).indexOf(animeJSON["id"].intValue){
                targetAnime = fetchedAnimes[found]
            }else{
                targetAnime = NSEntityDescription.insertNewObjectForNamedEntity(Animes.self, inManagedObjectContext: context)
                guard let anilistId = animeJSON["id"].int else { continue }
                targetAnime.animeAnilistId = anilistId
            }
            targetAnime.animeImgL = animeJSON["image_url_lge"].string
            targetAnime.animeImgM = animeJSON["image_url_med"].string
            targetAnime.animeImgS = animeJSON["image_url_sml"].string
            targetAnime.animePopularity = animeJSON["popularity"].int
            targetAnime.animeScore = animeJSON["average_score"].float
            targetAnime.animeStatus = animeJSON["airing_status"].string
            targetAnime.animeTitleEnglish = animeJSON["title_english"].string
            targetAnime.animeTitleJapanese = animeJSON["title_japanese"].string
            targetAnime.animeTotalEps = animeJSON["total_episodes"].int
            targetAnime.animeNextEps = animeJSON["airing"]["next_episode"].int
            targetAnime.animeNextEpsTime = animeJSON["airing"]["time"].date
            targetAnime.animeFlagTemp = NSNumber(bool: isTemp)
            targetAnime.animeOrder = self.insertIndexForTempEntries
            self.insertIndexForTempEntries += 1
        }
        
        do{ try context.save()} catch {
            print("Error saving new anime information")
            throw AnimeError.ErrorSavingCoreData
        }
        
        NSNotificationCenter.defaultCenter().postNotificationName(AnimeService.LocalAnimeDidUpdateNotification, object: self)
    }
    
    func ClearTempAnimes(){
        let context = CoreDataService.sharedCoreDataService.mainQueueContext
        let request = NSFetchRequest(namedEntity: Animes.self)
        request.predicate = NSPredicate(format: "animeFlagTemp == YES")
        context.deleteAllData(request)
        self.insertIndexForTempEntries = 0
    }
    
    static let sharedAnimeService = AnimeService()
}
