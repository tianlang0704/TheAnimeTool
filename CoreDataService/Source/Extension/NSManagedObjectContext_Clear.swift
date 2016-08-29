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
    func deleteAllData()
    {
        guard let persistentStore = persistentStoreCoordinator?.persistentStores.last else { return }
        guard let url = persistentStoreCoordinator?.URLForPersistentStore(persistentStore) else { return }
        
        performBlockAndWait { () -> Void in
            self.reset()
            do
            {
                try self.persistentStoreCoordinator?.removePersistentStore(persistentStore)
                try NSFileManager.defaultManager().removeItemAtURL(url)
                try self.persistentStoreCoordinator?.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: url, options: nil)
            }
            catch {
                print("Error clearing core data.")
            }
        }
    }
    
    func deleteAllData(request: NSFetchRequest){
        do{
            let objs = try self.executeFetchRequest(request) as! [NSManagedObject]
            for obj in objs{
                self.deleteObject(obj)
            }
        }catch{
            print("Error batch deleting request")
        }
    }
}
