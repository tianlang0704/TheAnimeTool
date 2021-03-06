//
//  VideoListViewController.swift
//  Fin
//
//  Created by Tieria C.Monk on 8/1/16.
//  Copyright © 2016 Tieria C.Monk. All rights reserved.
//

import UIKit
import CoreData

class VideoListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
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

        //add observer for video
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(HandleLocalVideosDidUpdate), name: VideoService.LocalVideosDidUpdateNotification, object: nil)
        
        //update local video list from torrent
        if let targetTorrent = self.torrentEntity {
            videoService = VideoService(torrentEntity: targetTorrent)
            videoService!.UpdateLocalVideo()
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
            self.videoService?.ClearCurrentTorrentEntityAndVideos()
            self.stopUpdatingVideoTable = true
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return self.videoResultsController?.sections?.count ?? 0
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return self.videoResultsController?.sections?[section].objects?.count ?? 0
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("VideoProtoCell1", forIndexPath: indexPath)
        let video = self.videoResultsController?.objectAtIndexPath(indexPath) as! Videos
        
        cell.selectionStyle = .None
        cell.textLabel?.text = video.videoName ?? ""
        cell.detailTextLabel?.text = "\(video.videoSize ?? 0)MB"
        
        guard let vs = self.videoService else { return cell }
        guard let index = video.videoIndex as? UInt else { return cell }
        let isDoNotDownload = vs.CheckIsDoNotDownloadForFileIndex(index) ?? true
        if !isDoNotDownload {
            let progress = vs.UpdateProgressForFileIndex(index)
            cell.detailTextLabel?.text?.appendContentsOf(" Progress:\(progress*100)%")
        }else{
            cell.detailTextLabel?.text?.appendContentsOf(" - Tap to start downloading")
        }
        
        return cell
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let video = self.videoResultsController?.objectAtIndexPath(indexPath) as! Videos
        guard let vs = self.videoService else { return }
        guard let index = video.videoIndex else { return }
        if vs.CheckIsDoNotDownloadForFileIndex(UInt(index)) ?? false {
            vs.SetDoNotDownloadForFileIndex(UInt(index), flag: false)
            dispatch_async(dispatch_get_main_queue(), {
                self.videoTableView.reloadData()
            })
        }
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        super.prepareForSegue(segue, sender: sender)
        
        if let s = sender as? UITableViewCell {
            guard let indexPath = videoTableView.indexPathForCell(s) else { return }
            guard let video = self.videoResultsController?.objectAtIndexPath(indexPath) as? Videos else { return }
            guard let videoIndex = video.videoIndex else { return }
            guard let vs = self.videoService else { return }
            vs.UpdateFilePathForFileIndex(UInt(videoIndex))
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

    /*
    // Override to support conditional editing of the table view.
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            // Delete the row from the data source
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
        } else if editingStyle == .Insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(tableView: UITableView, moveRowAtIndexPath fromIndexPath: NSIndexPath, toIndexPath: NSIndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(tableView: UITableView, canMoveRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */
    private func UpdateFetchedResults(){
        do{
            try self.videoResultsController?.performFetch()
        }catch{
            print("Error fetching torrents from core data")
        }
    }
    
    @objc private func HandleLocalVideosDidUpdate(notification: NSNotification){
        self.UpdateFetchedResults()
        dispatch_async(dispatch_get_main_queue(), {
            self.videoTableView.reloadData()
        })
    }
}
