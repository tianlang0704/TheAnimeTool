//
//  NSManagedObjectContext_Clear.swift
//  FinalProject
//
//  Created by Tieria C.Monk on 8/9/16.
//
//

import Foundation
import CoreData

extension NSManagedObjectContext
{
    typealias CompletionHandler = () -> Void
    
    func SaveRecursivelyToPersistentStorage(completionHandler: CompletionHandler = {}){
        self.performBlock(){
            do{ try self.save() }catch let error{print("Error saving context recursively: \(error)"); return}
            
            if let parentContext = self.parentContext{
                parentContext.SaveRecursivelyToPersistentStorage(completionHandler)
            }else{
                completionHandler()
            }
        }
    }
    
    func SaveRecursivelyToPersistentStorageAndWait(){
        self.performBlockAndWait(){
            do{ try self.save() }catch let error{print("Error saving context recursively: \(error)"); return}
            
            if let parentContext = self.parentContext{
                parentContext.SaveRecursivelyToPersistentStorage()
            }
        }
    }
    
    func deleteAllData()
    {
        guard let persistentStore = persistentStoreCoordinator?.persistentStores.last else { return }
        guard let url = persistentStoreCoordinator?.URLForPersistentStore(persistentStore) else { return }
        
        performBlockAndWait() {
            self.reset()
            do{
                try self.persistentStoreCoordinator?.removePersistentStore(persistentStore)
                try NSFileManager.defaultManager().removeItemAtURL(url)
                try self.persistentStoreCoordinator?.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: url, options: nil)
            }catch {
                print("Error clearing core data.")
            }
        }
    }
    
    func deleteAllData(request: NSFetchRequest){
        self.performBlockAndWait(){
            do{
                let objs = try self.executeFetchRequest(request) as! [NSManagedObject]
                for obj in objs{
                    self.deleteObject(obj)
                }
            }catch(let error){
                print("Error batch deleting request: \(error)")
            }
        }
    }
}
