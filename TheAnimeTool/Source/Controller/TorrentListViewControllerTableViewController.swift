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

class TorrentListViewController: UIViewController, UISearchBarDelegate, UITableViewDelegate, UITableViewDataSource {
    let defaultPredicate = NSPredicate(format: "torrentFlagTemp == YES")
    let defaultSortDescriptor = NSSortDescriptor(key: "torrentOrder", ascending: true)
    
    var animeEntity: Animes? = nil
    var torrentResultsController: NSFetchedResultsController? = nil
    @IBOutlet weak var torrentTableView: UITableView!
    @IBOutlet weak var torrentSearchBar: UISearchBar!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print(self.animeEntity)
        
        //initialize some settings for visual elements
        torrentSearchBar.enablesReturnKeyAutomatically = false
        
        //initialize fetched results controller
        let fetchRequest = NSFetchRequest(namedEntity: Torrents.self)
        fetchRequest.predicate = self.defaultPredicate
        fetchRequest.sortDescriptors = [self.defaultSortDescriptor]
        let context = CoreDataService.sharedCoreDataService.mainQueueContext
        self.torrentResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)
        
        //setup listeners for data change
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(HandleLocalTorrentDidUpdate), name: TorrentService.LocalTorrentsDidUpdateNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(HandleKeyboardWillShow), name: UIKeyboardWillShowNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(HandleKeyboardWillHide), name: UIKeyboardWillHideNotification, object: nil)
        
        //setup gesture recognizers
        let tap = UITapGestureRecognizer(target: self, action: #selector(TapHandler))
        tap.cancelsTouchesInView = false
        self.view.addGestureRecognizer(tap)
        
        //fetch data from Nyaa server
        let searchString = TorrentService.UtilMakeShortSearchString(self.animeEntity?.animeTitleEnglish ?? "")
        print(searchString)
        TorrentService.sharedTorrentService.UpdateTempTorrentsWith(searchString, sortBy: TorrentService.SortBy.Seeders)
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        if let idxs =  self.torrentTableView.indexPathsForSelectedRows{
            for idx in idxs{
                self.torrentTableView.deselectRowAtIndexPath(idx, animated: true)
            }
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
    
    func searchBar(searchBar: UISearchBar, textDidChange searchText: String) {
        self.FilterResultsWithString(searchText)
        self.torrentTableView.reloadData()
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
        
        //Generate the content of the cell
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
        do{
            try torrentResultsController?.performFetch()
        }catch{
            print("Error fetching torrents from core data")
        }
    }
    
    private func FilterResultsWithString(searchString: String){
        let context = CoreDataService.sharedCoreDataService.mainQueueContext
        let fetchRequest = NSFetchRequest(namedEntity: Torrents.self)
        if searchString == "" {
            fetchRequest.predicate = self.defaultPredicate
            fetchRequest.sortDescriptors = [self.defaultSortDescriptor]
        }else{
            let separatedString = searchString.componentsSeparatedByCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
            var subPredicates = [NSPredicate]()
            for subString in separatedString{
                guard subString.characters.count > 0 else { continue }
                subPredicates.append(NSPredicate(format: "torrentName CONTAINS[cd] \"\(subString)\" && torrentFlagTemp == YES"))
            }
            let filterPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: subPredicates)
            fetchRequest.predicate = filterPredicate
            fetchRequest.sortDescriptors = [self.defaultSortDescriptor]
        }
        self.torrentResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)
        UpdateFetchedResults()
    }
    
    @objc private func HandleLocalTorrentDidUpdate(notification: NSNotification){
        UpdateFetchedResults()
        self.torrentTableView.reloadData()
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
}
