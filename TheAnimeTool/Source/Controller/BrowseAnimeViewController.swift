//
//  ViewController.swift
//  Fin
//
//  Created by Tieria C.Monk on 8/1/16.
//  Copyright © 2016 Tieria C.Monk. All rights reserved.
//

import UIKit
import CoreData

class BrowseAnimeViewController: UIViewController, UISearchBarDelegate, UICollectionViewDelegate, UICollectionViewDataSource{
    
    var lastSearchString: String = ""
    var animeResultsController: NSFetchedResultsController? = nil
    @IBOutlet weak var animeCollectionView: UICollectionView!
    @IBOutlet weak var animeSearchBar: UISearchBar!
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        super.prepareForSegue(segue, sender: sender)
        let destination = segue.destinationViewController as! TorrentListViewController
        let indexPath = animeCollectionView.indexPathsForSelectedItems()?[0]
        
        guard let targetIndex = indexPath else { return }
        destination.animeEntity = animeResultsController?.objectAtIndexPath(targetIndex) as? Animes
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        //initialize some settings for visual elements
        animeSearchBar.enablesReturnKeyAutomatically = false
        let inset = animeCollectionView.frame.width * 0.018
        self.animeCollectionView.contentInset = UIEdgeInsets(top: inset, left: inset, bottom: inset, right: inset)
        
        //initialize fetched results controller
        let context = CoreDataService.sharedCoreDataService.mainQueueContext
        let fetchRequest = NSFetchRequest(namedEntity: Animes.self)
        fetchRequest.predicate = NSPredicate(format: "animeFlagTemp == YES")
        let sortDescriptor = NSSortDescriptor(key: "animeNextEpsTime", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]
        self.animeResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)
        self.UpdateFetchedResults()
        
        //setup listeners for data change
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(HandleLocalAnimeDidUpdate), name: AnimeService.LocalAnimeDidUpdateNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(HandleLocalAnimeUpdateFailed), name: AnimeService.LocalAnimeUpdateFailedNotification, object: nil)
        
        //setup gesture recognizers
        let tap = UITapGestureRecognizer(target: self, action: #selector(TapHandler))
        tap.cancelsTouchesInView = false
        self.view.addGestureRecognizer(tap)
        
        //fetch data from anilist server
        AnimeService.sharedAnimeService.UpdateTempWithAiringAnimes()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
        
        if let idxs = self.animeCollectionView.indexPathsForSelectedItems(){
            for idx in idxs{
                self.animeCollectionView.deselectItemAtIndexPath(idx, animated: true)
            }
        }
    }
    
    override func viewWillDisappear(animated: Bool) {
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func searchBarSearchButtonClicked(searchBar: UISearchBar) {
        guard let text = self.animeSearchBar.text else { return }
        self.SearchWithString(text)
        self.animeSearchBar.resignFirstResponder()
    }
    
    func searchBarCancelButtonClicked(searchBar: UISearchBar) {
        searchBar.text = ""
        self.SearchWithString("")
        searchBar.resignFirstResponder()
    }
    
    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return animeResultsController?.sections?.count ?? 0
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int{
        return animeResultsController?.sections?[section].objects?.count ?? 0
    }
    
    // The cell that is returned must be retrieved from a call to -dequeueReusableCellWithReuseIdentifier:forIndexPath:
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell{
        let cell = animeCollectionView.dequeueReusableCellWithReuseIdentifier("AnimeProtoCell1", forIndexPath: indexPath) as! AnimeCollectionViewCell
        guard let animeCheck = animeResultsController?.objectAtIndexPath(indexPath) else { return cell }
        let anime = animeCheck as! Animes
        
        //fill cell content
        let score = anime.animeScore ?? 0
        cell.shortDescription.text = String(format: "%@\nScore: %@", anime.animeTitleEnglish ?? "", score == 0 ? "N/A" : String(score))
        
        dispatch_async(dispatch_get_main_queue()) {cell.image.alpha = 0}
        UrlIf: if let urlString = anime.animeImgM {
            guard let url = NSURL(string: urlString) else { break UrlIf}
            
            let task = NSURLSession.sharedSession().dataTaskWithURL(url){(data, response, error) in
                guard let imgData = data else { return }
                let image = UIImage(data: imgData)
                dispatch_async(dispatch_get_main_queue()) {
                    cell.image.image = image
                    let animation = CABasicAnimation(keyPath: "opacity")
                    animation.duration = 0.5
                    animation.fromValue = 0
                    animation.toValue = 1
                    cell.image.layer.addAnimation(animation, forKey: "animateOpacity")
                    cell.image.alpha = 1
                }
            }
            task.resume()
        }
        
        //adjust cell visuals
        cell.shortDescription.layoutIfNeeded()
        cell.shortDescription.setContentOffset(CGPoint(x: 0, y: 5), animated: false)
        cell.shortDescription.textContainer.lineBreakMode = NSLineBreakMode.ByCharWrapping
        
        //shadows and round boarders
        cell.contentView.layer.cornerRadius = 3.0;
        cell.contentView.layer.borderWidth = 0.5;
        cell.contentView.layer.borderColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.9).CGColor
        cell.contentView.layer.masksToBounds = true;
        
        cell.layer.shadowColor = UIColor.blackColor().CGColor;
        cell.layer.shadowOffset = CGSizeMake(0, 0);
        cell.layer.shadowRadius = 2.0;
        cell.layer.shadowOpacity = 0.3;
        cell.layer.masksToBounds = false;
        cell.layer.shadowPath = UIBezierPath(roundedRect:cell.bounds, cornerRadius:cell.contentView.layer.cornerRadius).CGPath;
        
        return cell
    }
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
        let targetWidth = collectionView.frame.width * 0.29
        let targetHeight = targetWidth
        return CGSize(width: targetWidth, height: targetHeight)
    }
    
    private func UpdateFetchedResults(){
        do{
            try animeResultsController?.performFetch()
        }catch{
            print("Error fetching animes from core data")
        }
    }
    
    private func SearchWithString(searchString: String){
        guard searchString != self.lastSearchString else { return }
        
        self.lastSearchString = searchString
        if searchString == "" {
            AnimeService.sharedAnimeService.UpdateTempWithAiringAnimes()
        }else{
            AnimeService.sharedAnimeService.UpdateTempAnimesWithSearchString(searchString)
        }
    }
    
    @objc private func HandleLocalAnimeDidUpdate(notification: NSNotification){
        UpdateFetchedResults()
        self.animeCollectionView.reloadData()
    }
    
    @objc private func HandleLocalAnimeUpdateFailed(notification:NSNotification){
        let error = notification.object as! NSError
        switch error.code {
        case 4: //AnimeService.AnimeError.EmptyResult
            self.UpdateFetchedResults()
            self.animeCollectionView.reloadData()
            break
        default:
            break
        }
    }
    
    @objc private func TapHandler(){
        guard let text = self.animeSearchBar.text else { return }
        self.SearchWithString(text)
        self.animeSearchBar.resignFirstResponder()
    }
}

