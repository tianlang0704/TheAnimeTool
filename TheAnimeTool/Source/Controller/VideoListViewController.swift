//
//  VideoListViewController.swift
//  Fin
//
//  Created by Tieria C.Monk on 8/1/16.
//  Copyright © 2016 Tieria C.Monk. All rights reserved.
//

import UIKit
import CoreData

class VideoListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, NSFetchedResultsControllerDelegate {
    var torrentEntity: Torrents? = nil
    var videoResultsController: NSFetchedResultsController? = nil
    var videoService: VideoService? = nil
    var stopUpdatingVideoTable: Bool = false
    @IBOutlet weak var videoTableView: UITableView!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false
        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
        
        //init the results controller
        let fetchRequest = NSFetchRequest(namedEntity: Videos.self)
        let sortDescriptor = NSSortDescriptor(key: "videoName", ascending: true)
        fetchRequest.sortDescriptors = [sortDescriptor]
        let context = CoreDataService.sharedCoreDataService.mainQueueContext
        self.videoResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)
        self.videoResultsController?.delegate = self

        //add observer for video
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(HandleLocalVideosDidUpdate), name: VideoService.LocalVideosDidUpdateNotification, object: nil)
        
        //update local video list from torrent
        if let targetTorrent = self.torrentEntity {
            videoService = VideoService(torrentEntity: targetTorrent)
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        if self.isMovingToParentViewController(){
            //start updating the list
            self.stopUpdatingVideoTable = false
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)){
                while !self.stopUpdatingVideoTable{
                    dispatch_async(dispatch_get_main_queue(), {
                        self.videoTableView.reloadData()
                    })
                    sleep(1)
                }
            }
        }
    }
    
    override func viewWillDisappear(animated: Bool) {
        if self.isMovingFromParentViewController(){
            super.viewWillDisappear(animated)
            self.videoService?.ClearCurrentVideoEntities()
            self.stopUpdatingVideoTable = true
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return self.videoResultsController?.sections?.count ?? 0
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.videoResultsController?.sections?[section].objects?.count ?? 0
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("VideoProtoCell1", forIndexPath: indexPath)
        return self.ConfigureCell(cell, indexPath: indexPath)
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let video = self.videoResultsController?.objectAtIndexPath(indexPath) as! Videos
        guard let index = video.videoIndex else { return }
        guard let vs = self.videoService else { return }
        
        if vs.StartDownloadingVideoAtIndex(index.unsignedIntegerValue){
            vs.torrentEntity.torrentFlagSaved = NSNumber(bool: true)
            
            CoreDataService.sharedCoreDataService.mainQueueContext.SaveRecursivelyToPersistentStorage(){
                dispatch_async(dispatch_get_main_queue()) {
                    self.videoTableView.reloadData()
                }
            }
        }
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        super.prepareForSegue(segue, sender: sender)
        
        if let s = sender as? UITableViewCell {
            guard let indexPath = videoTableView.indexPathForCell(s) else { return }
            guard let video = self.videoResultsController?.objectAtIndexPath(indexPath) as? Videos else { return }
            guard let videoIndex = video.videoIndex else { return }
            guard let vs = self.videoService else { return }
            vs.UpdateFilePathForFileIndexAndWait(UInt(videoIndex))
            let destination = segue.destinationViewController as! VideoPlayerController
            destination.videoEntity = video
        }
    }
    
    override func shouldPerformSegueWithIdentifier(identifier: String, sender: AnyObject?) -> Bool {
        if let s = sender as? UITableViewCell {
            guard let indexPath = self.videoTableView.indexPathForCell(s) else { return false }
            guard let video = self.videoResultsController?.objectAtIndexPath(indexPath) as? Videos else { return false }
            return video.videoDownloadPercent == 1
        }
        
        return true
    }
    
    //MARK: - Fetch results controller delegates
    
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        self.videoTableView.beginUpdates()
    }
    
    func controller(controller: NSFetchedResultsController, didChangeSection sectionInfo: NSFetchedResultsSectionInfo, atIndex sectionIndex: Int, forChangeType type: NSFetchedResultsChangeType) {
        switch type {
        case .Insert:
            self.videoTableView.insertSections(NSIndexSet(index: sectionIndex), withRowAnimation: .Fade)
        case .Delete:
            self.videoTableView.deleteSections(NSIndexSet(index: sectionIndex), withRowAnimation: .Fade)
        default:
            break
        }
    }
    
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        switch(type) {
        case .Insert:
            guard let targetIndexPath = newIndexPath else { break }
            self.videoTableView.insertRowsAtIndexPaths([targetIndexPath], withRowAnimation: .Fade)
            break
            
        case .Delete:
            guard let targetIndexPath = indexPath else { break }
            self.videoTableView.deleteRowsAtIndexPaths([targetIndexPath], withRowAnimation: .Fade)
            break
            
        case .Update:
            guard let targetIndexPath = indexPath else { break }
            guard let targetCell = self.videoTableView.cellForRowAtIndexPath(targetIndexPath) else { break }
            self.ConfigureCell(targetCell, indexPath: targetIndexPath)
            break
            
        case .Move:
            guard let fromIndexPath = newIndexPath else { break }
            guard let toIndexPath = indexPath else { break }
            self.videoTableView.deleteRowsAtIndexPaths([fromIndexPath], withRowAnimation: .Fade)
            self.videoTableView.insertRowsAtIndexPaths([toIndexPath], withRowAnimation: .Fade)
            break
        }
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        self.videoTableView.endUpdates()
    }
    
    
    //MARK: - Notificatoin handler functions
    
    @objc private func HandleLocalVideosDidUpdate(notification: NSNotification){
        self.UpdateFetchedResults()
        dispatch_async(dispatch_get_main_queue(), {
            self.videoTableView.reloadData()
        })
    }
    

    //MARK: - Helper functions
    
    private func ConfigureCell(cell: UITableViewCell, indexPath: NSIndexPath) -> UITableViewCell{
        guard let video = self.videoResultsController?.objectAtIndexPath(indexPath) as? Videos else { return cell }
        
        cell.textLabel?.text = video.videoName ?? ""
        
        guard let vs = self.videoService else { return cell }
        guard let index = video.videoIndex as? UInt else { return cell }
        let isDoNotDownload = vs.CheckIsDoNotDownloadForFileIndex(index) ?? true
        if !isDoNotDownload {
            cell.detailTextLabel?.text = "\(video.videoSize ?? 0)MB Progress:\(vs.GetProgressForFileIndex(index)*100)%"
        }else{
            cell.detailTextLabel?.text = "\(video.videoSize ?? 0)MB - Tap to start downloading"
        }
        
        return cell
    }
    
    private func UpdateFetchedResults(){
        CoreDataService.sharedCoreDataService.mainQueueContext.performBlockAndWait(){
            do{
                try self.videoResultsController?.performFetch()
            }catch{
                print("Error fetching torrents from core data")
            }
        }
    }
}
