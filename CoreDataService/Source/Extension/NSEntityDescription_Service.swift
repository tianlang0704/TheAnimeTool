//
//  NSEntityDescription_Service.swift
//
//  Created by Charles Augustine.
//  Copyright (c) 2015 Charles Augustine. All rights reserved.
//


import CoreData
import Foundation


public extension NSEntityDescription {
	public class func insertNewObjectForNamedEntity<T:NSManagedObject where T:NamedEntity>(namedEntity: T.Type, inManagedObjectContext context: NSManagedObjectContext) -> T {
		return self.insertNewObjectForEntityForName(namedEntity.entityName, inManagedObjectContext: context) as! T
	}
}