//
//  VideoPlayerController.swift
//  FinalProject
//
//  Created by Tieria C.Monk on 8/18/16.
//
//

import AVKit

class VideoPlayerController: AVPlayerViewController {
    var videoEntity: Videos? = nil
    
    override func viewDidLoad() {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)){
            guard let video = self.videoEntity else { return }
            guard let videoPath = video.videoPath else { return }
            let url = NSURL(fileURLWithPath: videoPath)
            self.player = AVPlayer(URL: url)
            self.player?.play()
        }
    }
}
