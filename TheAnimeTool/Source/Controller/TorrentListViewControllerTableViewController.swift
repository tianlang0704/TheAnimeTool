//
//  TorrentListViewControllerTableViewController.swift
//  Fin
//
//  Created by Tieria C.Monk on 8/1/16.
//  Copyright © 2016 Tieria C.Monk. All rights reserved.
//

import UIKit
import CoreData
import PromiseKit
import NDHpple

class TorrentListViewController: UIViewController, UISearchBarDelegate, UITableViewDelegate, UITableViewDataSource/*, NSFetchedResultsControllerDelegate*/ {
    var defaultPredicateString = ""
    var defaultSortDescriptor = NSSortDescriptor(key: "torrentTempOrder", ascending: true)
    
    var animeEntity: Animes? = nil
    var torrentResultsController: NSFetchedResultsController? = nil
    @IBOutlet weak var torrentTableView: UITableView!
    @IBOutlet weak var torrentSearchBar: UISearchBar!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print(self.animeEntity)
        
        //initialize pre-requisites for fetched results controller
        let fetchRequest = NSFetchRequest(namedEntity: Torrents.self)
        fetchRequest.sortDescriptors = [self.defaultSortDescriptor]
        let context = CoreDataService.sharedCoreDataService.mainQueueContext
        
        //initialize some settings for visual elements
        torrentSearchBar.enablesReturnKeyAutomatically = false
        
        //setup listeners for data change
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(HandleLocalTorrentDidUpdate), name: TorrentService.LocalTorrentsDidUpdateNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(HandleKeyboardWillShow), name: UIKeyboardWillShowNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(HandleKeyboardWillHide), name: UIKeyboardWillHideNotification, object: nil)
        
        //setup gesture recognizers
        let tap = UITapGestureRecognizer(target: self, action: #selector(TapHandler))
        tap.cancelsTouchesInView = false
        self.view.addGestureRecognizer(tap)
        
        //split saved and browse anime
        if let animeEntity = self.animeEntity{
            //initialize torrent results controller
            self.defaultPredicateString = "torrentFlagTemp == YES"
            fetchRequest.predicate = NSPredicate(format: self.defaultPredicateString)
            self.torrentResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)
            //self.torrentResultsController?.delegate = self
            
            //fetch data from Nyaa server according to the selected anime
            let searchString = TorrentService.UtilMakeShortSearchString(animeEntity.animeTitleEnglish ?? "")
            print(searchString)
            TorrentService.sharedTorrentService.UpdateTempTorrentsWith(searchString, sortBy: TorrentService.SortBy.Seeders)
        }else{
            //initialize torrent results controller
            self.defaultPredicateString = "torrentFlagSaved == YES"
            fetchRequest.predicate = NSPredicate(format: self.defaultPredicateString)
            let context = CoreDataService.sharedCoreDataService.mainQueueContext
            self.torrentResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)
            //self.torrentResultsController?.delegate = self
            
            self.UpdateFetchedResults()
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        if !self.isMovingToParentViewController(){
            self.UpdateFetchedResults()
            dispatch_async(dispatch_get_main_queue()) {
                self.torrentTableView.reloadData()
            }
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        if let idxs =  self.torrentTableView.indexPathsForSelectedRows{
            for idx in idxs{
                self.torrentTableView.deselectRowAtIndexPath(idx, animated: true)
            }
        }
    }
    
    override func viewDidDisappear(animated: Bool) {
        if self.isMovingFromParentViewController(){
            self.torrentResultsController = nil
        }
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        super.prepareForSegue(segue, sender: sender)
        
        let destination = segue.destinationViewController as! VideoListViewController
        let indexPath = torrentTableView.indexPathsForSelectedRows?[0]
        
        guard let targetIndex = indexPath else { return }
        destination.torrentEntity = torrentResultsController?.objectAtIndexPath(targetIndex) as? Torrents
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
     // MARK: - Search bar delegates
    
    func searchBar(searchBar: UISearchBar, textDidChange searchText: String) {
        self.FilterResultsWithString(searchText)
        dispatch_async(dispatch_get_main_queue()) {
            self.torrentTableView.reloadData()
        }
    }

    func searchBarSearchButtonClicked(searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    // MARK: - Table view data source

    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return torrentResultsController?.sections?.count ?? 0
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return torrentResultsController?.sections?[section].objects?.count ?? 0
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("TorrentProtoCell1", forIndexPath: indexPath)
        self.ConfigureCell(cell, indexPath: indexPath)
        return cell
    }
    
//    //MARK: - Fetch results controller delegates
//    
//    func controllerWillChangeContent(controller: NSFetchedResultsController) {
//        self.torrentTableView.beginUpdates()
//    }
//
//    func controller(controller: NSFetchedResultsController, didChangeSection sectionInfo: NSFetchedResultsSectionInfo, atIndex sectionIndex: Int, forChangeType type: NSFetchedResultsChangeType) {
//        switch type {
//        case .Insert:
//            self.torrentTableView.insertSections(NSIndexSet(index: sectionIndex), withRowAnimation: .Fade)
//        case .Delete:
//            self.torrentTableView.deleteSections(NSIndexSet(index: sectionIndex), withRowAnimation: .Fade)
//        default:
//            break
//        }
//    }
//
//    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
//        switch(type) {
//        case .Insert:
//            guard let targetIndexPath = newIndexPath else { break }
//            self.torrentTableView.insertRowsAtIndexPaths([targetIndexPath], withRowAnimation: .Fade)
//            break
//
//        case .Delete:
//            guard let targetIndexPath = indexPath else { break }
//            self.torrentTableView.deleteRowsAtIndexPaths([targetIndexPath], withRowAnimation: .Fade)
//            break
//
//        case .Update:
//            guard let targetIndexPath = indexPath else { break }
//            guard let targetCell = self.torrentTableView.cellForRowAtIndexPath(targetIndexPath) else { break }
//            self.ConfigureCell(targetCell, indexPath: targetIndexPath)
//            break
//
//        case .Move:
//            guard let fromIndexPath = newIndexPath else { break }
//            guard let toIndexPath = indexPath else { break }
//            self.torrentTableView.deleteRowsAtIndexPaths([fromIndexPath], withRowAnimation: .Fade)
//            self.torrentTableView.insertRowsAtIndexPaths([toIndexPath], withRowAnimation: .Fade)
//            break
//        }
//    }
//    
//    func controllerDidChangeContent(controller: NSFetchedResultsController) {
//        self.torrentTableView.endUpdates()
//    }

    // MARK: - Notification handlers
    
    @objc private func HandleLocalTorrentDidUpdate(notification: NSNotification){
        self.UpdateFetchedResults()
        dispatch_async(dispatch_get_main_queue()) {
            self.torrentTableView.reloadData()
        }
    }
    @objc private func HandleKeyboardWillShow(noti: NSNotification){
        self.torrentTableView.adjustInsetsForWillShowKeyboardNotification(noti)
    }
    
    @objc private func HandleKeyboardWillHide(noti: NSNotification){
        self.torrentTableView.adjustInsetsForWillHideKeyboardNotification(noti)
    }
    
    @objc private func TapHandler(){
        self.torrentSearchBar.resignFirstResponder()
    }
    
    // MARK: - Helper functions
    
    private func ConfigureCell(cell: UITableViewCell, indexPath: NSIndexPath) -> UITableViewCell{
        let torrent = torrentResultsController?.objectAtIndexPath(indexPath) as! Torrents
        cell.textLabel?.text = torrent.torrentName
        cell.detailTextLabel?.text = String(format: "S:%@ L:%@ D:%@ Size:%@MB",
                                            torrent.torrentSeeders ?? 0,
                                            torrent.torrentLeechers ?? 0,
                                            torrent.torrentDownloads ?? 0,
                                            torrent.torrentSize ?? 0)
        return cell
    }
    
    private func UpdateFetchedResults(){
        CoreDataService.sharedCoreDataService.mainQueueContext.performBlockAndWait(){
            do{
                try self.torrentResultsController?.performFetch()
            }catch{
                print("Error fetching torrents from core data")
            }
        }
    }
    
    private func FilterResultsWithString(searchString: String){
        let context = CoreDataService.sharedCoreDataService.mainQueueContext
        let fetchRequest = NSFetchRequest(namedEntity: Torrents.self)
        if searchString == "" {
            fetchRequest.predicate = NSPredicate(format: self.defaultPredicateString)
            fetchRequest.sortDescriptors = [self.defaultSortDescriptor]
        }else{
            let separatedString = searchString.componentsSeparatedByCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
            var subPredicates = [NSPredicate]()
            for subString in separatedString{
                guard subString.characters.count > 0 else { continue }
                subPredicates.append(NSPredicate(format: "torrentName CONTAINS[cd] \"\(subString)\" && \(self.defaultPredicateString)"))
            }
            let filterPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: subPredicates)
            fetchRequest.predicate = filterPredicate
            fetchRequest.sortDescriptors = [self.defaultSortDescriptor]
        }
        self.torrentResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)
        self.UpdateFetchedResults()
    }
}
